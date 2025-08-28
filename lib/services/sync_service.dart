import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_transaction_service.dart';

class SyncService {
  static bool _syncing = false; // 🔒 lock to prevent concurrent syncs

  /// Connectivity().checkConnectivity() is not enough — use a server read.
  static Future<bool> isOnline() async {
    // Fast-path: if OS says "no network", skip trying server
    final status = await Connectivity().checkConnectivity();
    if (status == ConnectivityResult.none) return false;

    try {
      // Force a server read; if it throws, treat as offline
      await FirebaseFirestore.instance
          .collection('_ping')
          .limit(1)
          .get(const GetOptions(source: Source.server));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Main sync loop: deletes → uploads → updates
  static Future<void> syncTransactions() async {
    if (_syncing) {
      print("🔁 Sync already in progress, skipping duplicate call");
      return;
    }

    _syncing = true;
    final _localDb = LocalTransactionService();

    try {
      if (!await isOnline()) {
        print("📴 Offline (server unreachable). Skipping sync.");
        return;
      }

      // -------- 1) Process pending deletes FIRST --------
      final pendingDeletes = await _localDb.getPendingDeletes();
      for (final tx in pendingDeletes) {
        final localId = tx['id'] as int;
        final remoteId = tx['remote_id'] as String?;
        try {
          if (remoteId != null && remoteId.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('transactions')
                .doc(remoteId)
                .delete();
            print("🗑️ Deleted remote doc $remoteId for local $localId");
          } else {
            // No remote yet — nothing to delete remotely.
            print("ℹ️ No remote_id for locally deleted tx $localId, skipping remote delete");
          }

          // Always remove local row once "deleted" intention is processed
          await _localDb.hardDeleteTransaction(localId);
        } catch (e) {
          print("❌ Failed to delete remote for tx $localId: $e");
          // keep the row (deleted=1) so we can retry next sync
        }
      }

      // -------- 2) Upload brand-new (unsynced) --------
      final unsynced = await _localDb.getUnsyncedTransactions();
      for (final tx in unsynced) {
        try {
          final referenceNumber = tx['reference_number'];

          // de-dupe by reference_number
          final existing = await FirebaseFirestore.instance
              .collection('transactions')
              .where('reference_number', isEqualTo: referenceNumber)
              .limit(1)
              .get();

          if (existing.docs.isNotEmpty) {
            await _localDb.markAsSynced(tx['id'] as int, existing.docs.first.id);
            continue;
          }

          final docRef = await FirebaseFirestore.instance
              .collection('transactions')
              .add({
            'customer_name': tx['customer_name'],
            'items': jsonDecode(tx['items'] as String),
            'total_price': tx['total_price'],
            'created_at': Timestamp.fromDate(
              DateTime.parse(tx['created_at'] as String),
            ),
            'reference_number': referenceNumber,
            'status': (tx['status'] as String?) ?? 'unpaid',
            'payment': (tx['payment'] as String?) ?? 'cash',
          });

          await _localDb.markAsSynced(tx['id'] as int, docRef.id);
        } catch (e) {
          print("❌ Sync failed for unsynced tx ${tx['id']}: $e");
        }
      }

      // -------- 3) Push dirty updates --------
      final dirty = await _localDb.getDirtyTransactions();
      for (final tx in dirty) {
        try {
          final remoteId = tx['remote_id'] as String?;
          if (remoteId == null || remoteId.isEmpty) continue;

          await FirebaseFirestore.instance
              .collection('transactions')
              .doc(remoteId)
              .update({
            'status': tx['status'],
            'payment': (tx['payment'] as String?) ?? 'cash',
          });

          await _localDb.clearDirtyFlag(tx['id'] as int);
        } catch (e) {
          print("❌ Dirty sync failed for tx ${tx['id']}: $e");
        }
      }

      print("✅ Sync complete");
    } finally {
      _syncing = false;
    }
  }

  /// Remote → local refresh (keeps status/payment in sync)
  static Future<void> syncFromRemote() async {
    if (!await isOnline()) {
      print("📴 Offline (server unreachable). Skipping remote->local.");
      return;
    }

    final _localDb = LocalTransactionService();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final referenceNumber = data['reference_number'] as String?;

        if (referenceNumber == null) continue;

        final db = await _localDb.database;
        final local = await db.query(
          'transactions',
          where: 'reference_number = ?',
          whereArgs: [referenceNumber],
          limit: 1,
        );

        if (local.isNotEmpty) {
          final localId = local.first['id'] as int;
          final localStatus = (local.first['status'] as String?) ?? 'unpaid';
          final remoteStatus = (data['status'] as String?) ?? 'unpaid';

          if (localStatus != remoteStatus) {
            await _localDb.updateTransactionStatus(localId, remoteStatus);
            // mark dirty=1, but that's okay; it will be cleared when pushing (no-op)
          }

          final localPayment = (local.first['payment'] as String?) ?? 'cash';
          final remotePayment = (data['payment'] as String?) ?? 'cash';
          if (localPayment != remotePayment) {
            await _localDb.updateTransactionPayment(localId, remotePayment);
          }
        }
      }

      print("✅ Remote-to-local sync complete");
    } catch (e) {
      print("❌ Remote sync failed: $e");
    }
  }

  /// Public entry point for UI delete:
  /// - marks local row as deleted
  /// - then attempts to sync (which will remove remote and hard-delete local)
  static Future<void> requestDelete(int localId) async {
    final _localDb = LocalTransactionService();
    await _localDb.softDeleteTransaction(localId);
    await syncTransactions();
  }

  /// Optional helper: force local removal without touching remote
  static Future<void> deleteLocalOnly(int localId) async {
    final _localDb = LocalTransactionService();
    await _localDb.hardDeleteTransaction(localId);
  }
}
