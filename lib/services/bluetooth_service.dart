import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/cart_model.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_esc_pos_utils/flutter_esc_pos_utils.dart';
import 'package:image/image.dart' as img;

class BluetoothPrinterService {
  static const _printerMacKey = 'selected_printer_mac';

  Future<List<BluetoothInfo>> getBondedDevices() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  Future<void> savePrinterMac(String mac) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_printerMacKey, mac);
  }

  Future<String?> getSavedPrinterMac() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_printerMacKey);
  }

  Future<void> printReceipt(
  List<CartItem> items, {
  String? customerName,
  String? referenceNumber,
}) async {
  final savedMac = await getSavedPrinterMac();
  if (savedMac == null) throw Exception("No saved printer");

  final isConnected = await PrintBluetoothThermal.connectionStatus;
  if (!isConnected) {
    final connected = await PrintBluetoothThermal.connect(macPrinterAddress: savedMac);
    if (!connected) throw Exception("Failed to connect to printer");
  }

  List<int> bytes = [];

  final ByteData data = await rootBundle.load('assets/icon/app_icon_light.png');
  final Uint8List imageBytes = data.buffer.asUint8List();
  final img.Image? logo = img.decodeImage(imageBytes);

  final profile = await CapabilityProfile.load();
  final generator = Generator(PaperSize.mm58, profile);

  if (logo != null) {
    final img.Image resized = img.copyResize(logo, width: 200);
    bytes += generator.image(resized);
  }

  bytes += generator.feed(1);

  if (customerName != null && customerName.trim().isNotEmpty) {
    bytes += generator.text('Customer: $customerName',
        styles: const PosStyles(align: PosAlign.center, bold: true));
  }

  if (referenceNumber != null && referenceNumber.trim().isNotEmpty) {
    bytes += generator.text('Ref #: $referenceNumber',
        styles: const PosStyles(align: PosAlign.center, bold: true));
  }

  bytes += generator.text('Date: ${DateTime.now().toString().substring(0, 16)}');
  bytes += generator.text('-----------------------------');

  for (var item in items) {
    final lineTotal = item.price * item.quantity;
    String itemTitle = item.name;
    List<String> tags = [];

    if (item.temperature != 'none') tags.add(item.temperature);
    if (item.milk != 'none') tags.add(item.milk == 'oat' ? 'oat milk' : item.milk);
    if (item.size.isNotEmpty) tags.add(item.size);

    if (tags.isNotEmpty) {
      itemTitle += ' (${tags.join(', ')})';
    }

    bytes += generator.text(itemTitle, styles: const PosStyles(bold: true));
    bytes += generator.row([
      PosColumn(text: '${item.quantity} x ${item.price.toStringAsFixed(2)}', width: 6),
      PosColumn(
        text: 'Php ${lineTotal.toStringAsFixed(2)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.text('');
  }

  bytes += generator.text('-----------------------------');

  final total = items.fold<double>(0.0, (sum, i) => sum + i.price * i.quantity);

  bytes += generator.row([
    PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
    PosColumn(
      text: 'Php ${total.toStringAsFixed(2)}',
      width: 6,
      styles: const PosStyles(align: PosAlign.right, bold: true),
    ),
  ]);

  bytes += generator.feed(1);
  bytes += generator.text('Thank You and Enjoy!', styles: const PosStyles(align: PosAlign.center));
  bytes += generator.feed(2);

  final result = await PrintBluetoothThermal.writeBytes(bytes);
  if (!result) throw Exception("Failed to print receipt");
}

}
