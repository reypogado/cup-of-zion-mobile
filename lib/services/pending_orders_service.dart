import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/pending_order_model.dart';
import 'local_transaction_service.dart';
import 'sync_service.dart';

/// Reads and works the `pending-orders` queue that the web app writes to.
/// Mirrors coz-web-page/src/context/OrdersContext.tsx.
class PendingOrdersService {
  static const String collection = 'pending-orders';

  static CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection(collection);

  final LocalTransactionService _localDb = LocalTransactionService();

  /// Live queue, newest first.
  Stream<List<PendingOrder>> watchOrders() {
    return _col.snapshots().map((snap) {
      final orders = snap.docs
          .map((d) => PendingOrder.fromDoc(d.id, d.data()))
          .toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  /// Move the order along the kitchen workflow.
  Future<void> setStatus(PendingOrder order, OrderStatus status) async {
    if (order.status == status) return;
    await _col.doc(order.id).update({'status': status.id});
  }

  /// Finish the order: record it as a transaction, then drop it from the queue.
  ///
  /// The transaction is written to the local database (keeping the order's
  /// reference number) so it shows up in Records right away and survives being
  /// offline; SyncService pushes it to Firestore on its next pass.
  Future<void> complete(
    PendingOrder order, {
    required String paymentStatus, // 'paid' | 'unpaid'
    String payment = 'cash',
  }) async {
    final reference = order.reference.isEmpty
        ? 'COZ-${order.id}'
        : order.reference;

    await _localDb.insertTransaction(
      customerName: order.customerName.isEmpty ? null : order.customerName,
      items: order.items.map((i) => i.toTransactionJson()).toList(),
      totalPrice: order.total,
      status: paymentStatus,
      payment: payment,
      reference: reference,
      createdAt: order.createdAt,
    );

    try {
      await _col.doc(order.id).delete();
    } catch (e) {
      // Roll back so the order can't be recorded twice on a retry.
      await _localDb.hardDeleteByReference(reference);
      rethrow;
    }

    // Fire-and-forget: get it up to Firestore when we can.
    SyncService.syncTransactions();
  }

  /// Discard an order without recording it anywhere.
  Future<void> remove(PendingOrder order) => _col.doc(order.id).delete();

  /// Discard every queued order without recording them.
  Future<void> clearAll(List<PendingOrder> orders) async {
    await Future.wait(orders.map((o) => _col.doc(o.id).delete()));
  }
}
