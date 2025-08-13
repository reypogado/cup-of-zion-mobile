import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_transaction_service.dart';

class SyncService {
  static bool _syncing = false; // 🔒 lock to prevent double syncs

  static Future<bool> isOnline() async {
    final status = await Connectivity().checkConnectivity();
    return status != ConnectivityResult.none;
  }

  static Future<void> syncTransactions() async {
    if (_syncing) {
      print("🔁 Sync already in progress, skipping duplicate call");
      return;
    }

    _syncing = true; // lock sync

    final _localDb = LocalTransactionService();

    try {
      if (!await isOnline()) return;

      final unsynced = await _localDb.getUnsyncedTransactions();
      final dirty = await _localDb.getDirtyTransactions();

      // Upload new (unsynced) transactions
      for (final tx in unsynced) {
        try {
          final referenceNumber = tx['reference_number'];

          final existing = await FirebaseFirestore.instance
              .collection('transactions')
              .where('reference_number', isEqualTo: referenceNumber)
              .limit(1)
              .get();

          if (existing.docs.isNotEmpty) {
            await _localDb.markAsSynced(tx['id'], existing.docs.first.id);
            continue;
          }

          final docRef = await FirebaseFirestore.instance
              .collection('transactions')
              .add({
                'customer_name': tx['customer_name'],
                'items': jsonDecode(tx['items']),
                'total_price': tx['total_price'],
                'created_at': Timestamp.fromDate(
                  DateTime.parse(tx['created_at']),
                ),
                'reference_number': referenceNumber,
                'status': tx['status'] ?? 'unpaid',
                'payment': tx['payment'] ?? 'cash',
              });

          await _localDb.markAsSynced(tx['id'], docRef.id);
        } catch (e) {
          print("❌ Sync failed for unsynced tx ${tx['id']}: $e");
        }
      }

      // Sync dirty status updates
      for (final tx in dirty) {
        try {
          await FirebaseFirestore.instance
              .collection('transactions')
              .doc(tx['remote_id'])
              .update({
                'status': tx['status'],
                'payment': tx['payment'] ?? 'cash', // ✅ Add this line
              });

          await _localDb.clearDirtyFlag(tx['id']);
        } catch (e) {
          print("❌ Dirty sync failed for tx ${tx['id']}: $e");
        }
      }
    } finally {
      _syncing = false; // 🔓 unlock
    }
  }

  // sync from remote
  // trigger: await SyncService.syncFromRemote();
  static Future<void> syncFromRemote() async {
    final _localDb = LocalTransactionService();

    if (!await isOnline()) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('transactions')
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final referenceNumber = data['reference_number'];

        final db = await _localDb.database;
        final local = await db.query(
          'transactions',
          where: 'reference_number = ?',
          whereArgs: [referenceNumber],
          limit: 1,
        );

        if (local.isNotEmpty) {
          final localId = local.first['id'] as int;
          final localStatus = local.first['status'] as String? ?? 'unpaid';
          final remoteStatus = data['status'] as String? ?? 'unpaid';

          if (localStatus != remoteStatus) {
            await _localDb.updateTransactionStatus(localId, remoteStatus);
          }
        }
      }

      print("✅ Remote-to-local sync complete");
    } catch (e) {
      print("❌ Remote sync failed: $e");
    }
  }

  static Future<void> deleteTransaction(int localId) async {
    final _localDb = LocalTransactionService();
    final remoteId = await _localDb.getRemoteId(localId);

    if (remoteId != null && remoteId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('transactions')
            .doc(remoteId)
            .delete();
        print("✅ Firestore record deleted: $remoteId");
      } catch (e) {
        print("❌ Failed to delete from Firestore: $e");
      }
    }

    await _localDb.deleteTransaction(localId);
  }
}
