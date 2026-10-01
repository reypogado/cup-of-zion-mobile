import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../data/pending_order_model.dart';
import '../../services/pending_orders_service.dart';

const Color _primary = Color(0xFF1B3B34);

/// The kitchen queue — orders placed from the web app, waiting to be made.
/// Mirrors coz-web-page/src/pages/PendingOrdersPage.tsx.
class PendingOrdersScreen extends StatefulWidget {
  const PendingOrdersScreen({super.key});

  @override
  State<PendingOrdersScreen> createState() => _PendingOrdersScreenState();
}

class _PendingOrdersScreenState extends State<PendingOrdersScreen> {
  final _service = PendingOrdersService();
  String? _busyOrderId;

  static const _statusColors = {
    OrderStatus.pending: Color(0xFFB45309),
    OrderStatus.making: Color(0xFF0369A1),
    OrderStatus.serving: Color(0xFF047857),
  };

  static const _statusBackgrounds = {
    OrderStatus.pending: Color(0xFFFEF3C7),
    OrderStatus.making: Color(0xFFE0F2FE),
    OrderStatus.serving: Color(0xFFD1FAE5),
  };

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
    );
  }

  Future<void> _changeStatus(PendingOrder order, OrderStatus status) async {
    try {
      await _service.setStatus(order, status);
    } catch (e) {
      _showError('Could not update status: $e');
    }
  }

  Future<void> _cancelOrder(PendingOrder order) async {
    final who = order.customerName.isEmpty ? '' : ' for ${order.customerName}';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text(
          'Cancel order ${order.reference}$who? This permanently deletes it and '
          'is NOT recorded in transactions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busyOrderId = order.id);
    try {
      await _service.remove(order);
    } catch (e) {
      _showError('Could not cancel the order: $e');
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

  Future<void> _clearAll(List<PendingOrder> orders) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All'),
        content: const Text(
          'Clear ALL pending orders without recording them? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _service.clearAll(orders);
    } catch (e) {
      _showError('Could not clear the queue: $e');
    }
  }

  Future<void> _markDone(PendingOrder order) async {
    final paymentStatus = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${order.reference} · ${order.displayName} · '
              'Php ${order.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Mark this order as paid or unpaid? It will be moved to Records.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'unpaid'),
            child: const Text('Unpaid'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'paid'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Paid'),
          ),
        ],
      ),
    );
    if (paymentStatus == null) return;

    setState(() => _busyOrderId = order.id);
    try {
      await _service.complete(order, paymentStatus: paymentStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${order.reference} recorded as $paymentStatus.'),
          backgroundColor: Colors.green[800],
        ),
      );
    } catch (e) {
      _showError('Could not complete the order: $e');
    } finally {
      if (mounted) setState(() => _busyOrderId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pending Orders'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<PendingOrder>>(
        stream: _service.watchOrders(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildError('${snapshot.error}');
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) return _buildEmpty();

          final grandTotal = orders.fold<double>(0, (sum, o) => sum + o.total);

          return Column(
            children: [
              _buildSummary(orders.length, grandTotal, orders),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                  itemCount: orders.length,
                  itemBuilder: (context, i) => _buildOrderCard(orders[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              "Couldn't reach Firestore",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            'No pending orders',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Orders submitted from the website appear here.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(int count, double grandTotal, List<PendingOrder> orders) {
    return Container(
      width: double.infinity,
      color: _primary,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count pending order${count > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Outstanding: Php ${grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _clearAll(orders),
            child: const Text(
              'Clear all',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(PendingOrder order) {
    final busy = _busyOrderId == order.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(order),
          const Divider(height: 1),
          ...order.items.map(_buildItemRow),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: _buildStatusSwitcher(order),
          ),
          const Divider(height: 1),
          _buildCardFooter(order, busy),
        ],
      ),
    );
  }

  Widget _buildCardHeader(PendingOrder order) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        order.reference,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _statusBackgrounds[order.status],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        order.status.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _statusColors[order.status],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  order.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (order.phone.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: order.phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${order.phone} copied'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            order.phone,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM d, h:mm a').format(order.createdAt),
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(PendingOrderItem item) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: item.assetPath.isEmpty
                ? const Icon(Icons.local_cafe_outlined, color: Colors.grey)
                : Image.asset(
                    item.assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.local_cafe_outlined, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.quantity}× ${item.name}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Php ${item.lineTotal.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSwitcher(PendingOrder order) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: OrderStatus.values.map((status) {
          final active = order.status == status;
          return Expanded(
            child: GestureDetector(
              onTap: () => _changeStatus(order, status),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? _statusColors[status] : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : Colors.grey[600],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCardFooter(PendingOrder order, bool busy) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total',
                style: TextStyle(fontSize: 10, color: Colors.grey[500]),
              ),
              Text(
                'Php ${order.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: _primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          OutlinedButton.icon(
            onPressed: busy ? null : () => _cancelOrder(order),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Cancel'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Color(0xFFFECACA)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: busy ? null : () => _markDone(order),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Done'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
