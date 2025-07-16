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

  Future<void> printReceipt(List<CartItem> items) async {
    // Reconnect to the saved printer
    final savedMac = await getSavedPrinterMac();
    if (savedMac == null) {
      throw Exception("No saved printer");
    }

    final isConnected = await PrintBluetoothThermal.connectionStatus;
    if (!isConnected) {
      final connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: savedMac,
      );
      if (!connected) throw Exception("Failed to connect to printer");
    }

    List<int> bytes = [];

    // Load and decode logo
    final ByteData data = await rootBundle.load('assets/icon/app_icon_light.png');
    final Uint8List imageBytes = data.buffer.asUint8List();
    final img.Image? logo = img.decodeImage(imageBytes);

    // Generate ESC/POS bytes
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);

    if (logo != null) {
      // Resize to a safe width (e.g. 200px), keep aspect ratio
      final img.Image resized = img.copyResize(logo, width: 200);
      bytes += generator.image(resized);
    }


    // bytes += generator.feed(1);
    bytes += generator.text('Date: ${DateTime.now()}');
    bytes += generator.text('-----------------------------');

    for (var item in items) {
      bytes += generator.row([
        PosColumn(text: item.name, width: 10),
        PosColumn(
          text: 'x${item.quantity}',
          width: 2,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.text('-----------------------------');
    final total = items.fold<double>(
      0.0,
      (sum, i) => sum + i.price * i.quantity,
    );
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(
        text: 'Php ${total.toStringAsFixed(2)}',
        width: 6,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.feed(1);
    bytes += generator.text(
      'Thank you!',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.feed(2);

    // Send to printer
    final result = await PrintBluetoothThermal.writeBytes(bytes);
    if (!result) throw Exception("Failed to print receipt");
  }
}
