import 'package:cup_of_zion/data/cart_model.dart';
import 'package:cup_of_zion/services/bluetooth_service.dart';
import 'package:cup_of_zion/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/local_transaction_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

class TransactionRecordsScreen extends StatefulWidget {
  const TransactionRecordsScreen({super.key});

  @override
  State<TransactionRecordsScreen> createState() =>
      _TransactionRecordsScreenState();
}

class _TransactionRecordsScreenState extends State<TransactionRecordsScreen> {
  final _localDb = LocalTransactionService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _transactions = [];

  DateTime? _startDate;
  DateTime? _endDate;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day, 0, 0, 0);
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    _loadTransactions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    final data = await _localDb.getAllTransactions(
      start: _startDate,
      end: _endDate,
    );

    setState(() {
      _transactions = data.where((tx) {
        final deleted = (tx['deleted'] ?? 0) == 1; // ← guard
        final name = (tx['customer_name'] ?? '').toString().toLowerCase();
        final matches = name.contains(_searchQuery.toLowerCase());
        return !deleted && matches; // ← hide if deleted
      }).toList();
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
          0,
          0,
          0,
        );
        _endDate = DateTime(
          picked.end.year,
          picked.end.month,
          picked.end.day,
          23,
          59,
          59,
          999,
        );
      });
      _loadTransactions();
    }
  }

  Future<void> _confirmAndDelete(Map<String, dynamic> tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Transaction"),
        content: const Text(
          "Are you sure you want to delete this transaction?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final id = tx['id'] as int;

      // ✅ Mark for deletion and let SyncService handle remote + hard delete
      await SyncService.requestDelete(id);

      // ❌ Remove this direct Firestore delete block:
      // if (tx['remote_id'] != null) { ... }

      await _loadTransactions();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Transaction deleted"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showEditField({
    required String title,
    required String label,
    required String initialValue,
    required Future<void> Function(String) onSave,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLines: label == 'Note' ? 3 : 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B3B34),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final text = controller.text.trim();
    // Defer dispose so Flutter's close animation and focus events finish first
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (confirmed == true) {
      await onSave(text);
    }
  }

  /// "Cafe Latte x2 (hot, oat milk, large, 2x premium shot, Espresso Shot)"
  String _describeItem(Map<String, dynamic> item) {
    final tags = <String>[
      if ((item['temperature'] ?? '').toString().isNotEmpty &&
          item['temperature'] != 'none')
        item['temperature'].toString(),
      if ((item['milk'] ?? '').toString().isNotEmpty && item['milk'] != 'none')
        '${item['milk']} milk',
      if ((item['size'] ?? '').toString().isNotEmpty) item['size'].toString(),
      if ((item['drinkOptions'] ?? '').toString().isNotEmpty)
        item['drinkOptions'].toString(),
      ...((item['addOns'] as List?) ?? []).map((a) => (a['name'] ?? '').toString()),
    ];

    final title = "${item['name']} x${item['quantity']}";
    return tags.isEmpty ? title : "$title (${tags.join(', ')})";
  }

  void _showTransactionDetails(Map<String, dynamic> tx) {
    final items = List<Map<String, dynamic>>.from(jsonDecode(tx['items']));
    final printerService = BluetoothPrinterService();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Transaction Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Customer: ${tx['customer_name'] ?? 'N/A'}"),
              const SizedBox(height: 8),
              if ((tx['note'] ?? '').toString().isNotEmpty) ...[
                Text(
                  "Note: ${tx['note']}",
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
              ],
              Text("Total: Php ${tx['total_price']}"),
              const SizedBox(height: 8),
              Text("Status: ${tx['status'] ?? ''}"),
              const SizedBox(height: 8),
              const Text("Items:"),
              ...items.map(
                (item) => Text("• ${_describeItem(item)}"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _showEditField(
                title: 'Edit Customer Name',
                label: 'Customer Name',
                initialValue: tx['customer_name'] ?? '',
                onSave: (value) async {
                  await _localDb.updateTransactionCustomerName(tx['id'], value);
                  _loadTransactions();
                },
              );
            },
            child: const Text("Edit Name"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _showEditField(
                title: (tx['note'] ?? '').toString().isEmpty
                    ? 'Add Note'
                    : 'Edit Note',
                label: 'Note',
                initialValue: tx['note'] ?? '',
                onSave: (value) async {
                  await _localDb.updateTransactionNote(tx['id'], value);
                  _loadTransactions();
                },
              );
            },
            child: Text(
              (tx['note'] ?? '').toString().isEmpty ? 'Add Note' : 'Edit Note',
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _confirmAndDelete(tx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () async {
              final newStatus = tx['status'] == 'paid' ? 'unpaid' : 'paid';
              await _localDb.updateTransactionStatus(tx['id'], newStatus);
              Navigator.pop(context);
              _loadTransactions();
            },
            child: Text(
              tx['status'] == 'paid' ? 'Mark as Unpaid' : 'Mark as Paid',
              style: TextStyle(
                color: tx['status'] == 'paid' ? Colors.red : Colors.green,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newPayment = tx['payment'] == 'cash' ? 'gcash' : 'cash';
              await _localDb.updateTransactionPayment(tx['id'], newPayment);
              Navigator.pop(context);
              _loadTransactions();
            },
            child: Text(
              tx['payment'] == 'cash' ? 'Update to GCash' : 'Update to Cash',
              style: const TextStyle(color: Colors.blue),
            ),
          ),

          ElevatedButton.icon(
            icon: const Icon(Icons.print),
            label: const Text("Reprint"),
            onPressed: () async {
              try {
                await printerService.printReceipt(
                  items
                      .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
                      .toList(),
                  customerName: tx['customer_name'],
                  referenceNumber: tx['reference_number'],
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Reprint successful"),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Failed to print: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    if (status == 'paid') {
      return const Chip(
        label: Text("Paid"),
        backgroundColor: Colors.green,
        labelStyle: TextStyle(color: Colors.white),
      );
    } else if (status == 'unpaid') {
      return const Chip(
        label: Text("Unpaid"),
        backgroundColor: Colors.red,
        labelStyle: TextStyle(color: Colors.white),
      );
    } else {
      return const SizedBox(); // empty
    }
  }

  Widget _buildPaymentChip(String? payment) {
    if (payment == 'gcash') {
      return const Chip(
        label: Text("GCash"),
        backgroundColor: Color(0xff1D72FB),
        labelStyle: TextStyle(color: Colors.white),
      );
    } else {
      return const Chip(
        label: Text("Cash"),
        backgroundColor: Colors.amber,
        labelStyle: TextStyle(color: Colors.white),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Transaction Records"),
        backgroundColor: const Color(0xFF1B3B34),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                _startDate != null
                    ? DateFormat("MMM dd").format(_startDate!) +
                          (_endDate != null && _endDate != _startDate
                              ? ' - ${DateFormat("MMM dd").format(_endDate!)}'
                              : '')
                    : '',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _pickDateRange,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search customer name...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                          _loadTransactions();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _loadTransactions();
              },
            ),
          ),
          Expanded(
            child: _transactions.isEmpty
                ? const Center(child: Text("No transactions found."))
                : ListView.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final tx = _transactions[index];
                      final date = DateFormat(
                        "yyyy-MM-dd HH:mm",
                      ).format(DateTime.parse(tx['created_at']));
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(
                            "Customer: ${tx['customer_name'] ?? 'N/A'}",
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Total: Php ${tx['total_price']}"),
                              Text("Date: $date"),
                              if ((tx['note'] ?? '').toString().isNotEmpty)
                                Text(
                                  "Note: ${tx['note']}",
                                  style: const TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildStatusChip(tx['status']),
                              const SizedBox(width: 10),
                              _buildPaymentChip(tx['payment']),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () => _showTransactionDetails(tx),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
