import 'package:cup_of_zion/services/bluetooth_service.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<BluetoothInfo> _printers = [];
  String? _selectedMac;
  final _service = BluetoothPrinterService();

  @override
  void initState() {
    super.initState();
    _loadPrinters();
  }

  Future<void> _loadPrinters() async {
    final devices = await _service.getBondedDevices();
    final savedMac = await _service.getSavedPrinterMac();
    setState(() {
      _printers = devices;
      _selectedMac = savedMac;
    });
  }

  void _selectPrinter(String mac) async {
    await _service.savePrinterMac(mac);
    setState(() {
      _selectedMac = mac;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Printer saved as default')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printer Settings')),
      body: ListView.builder(
        itemCount: _printers.length,
        itemBuilder: (context, index) {
          final printer = _printers[index];
          return ListTile(
            title: Text(printer.name),
            subtitle: Text(printer.macAdress),
            trailing: _selectedMac == printer.macAdress
                ? const Icon(Icons.check_circle, color: Colors.green)
                : null,
            onTap: () => _selectPrinter(printer.macAdress),
          );
        },
      ),
    );
  }
}
