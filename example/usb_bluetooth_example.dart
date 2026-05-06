// USB and Bluetooth example for star_prnt_flutter.
//
// Run on a real iOS or Android device — discovery requires the native SDK
// and (for Bluetooth on iOS) a paired Star printer in iOS Settings.

import 'package:star_prnt_flutter/star_prnt_flutter.dart';

Future<void> main() async {
  await discoverEverything();
  // await connectToFirstUsbPrinter();
  // await connectToFirstBluetoothPrinter();
}

/// Find every Star printer the native SDK can see (USB, Bluetooth, LAN).
Future<void> discoverEverything() async {
  final printers = await PrinterDiscovery.discoverNative();
  if (printers.isEmpty) {
    print('No printers found.');
    print('  - On iOS, pair Bluetooth printers in Settings first.');
    print('  - On Android 12+, request bluetoothConnect / bluetoothScan at runtime.');
    return;
  }
  for (final p in printers) {
    print('${p.connectionType.name.padRight(10)}  '
        '${p.portName ?? p.ipAddress}  '
        '(${p.modelName ?? 'unknown model'})');
  }
}

/// Filter to a single transport.
Future<void> connectToFirstUsbPrinter() async {
  final usb = await PrinterDiscovery.discoverNative(
    target: NativeDiscoveryTarget.usb,
  );
  if (usb.isEmpty) {
    print('No USB printers found.');
    return;
  }
  await _printHello(usb.first);
}

Future<void> connectToFirstBluetoothPrinter() async {
  final bt = await PrinterDiscovery.discoverNative(
    target: NativeDiscoveryTarget.bluetooth,
  );
  if (bt.isEmpty) {
    print('No Bluetooth printers found.');
    return;
  }
  await _printHello(bt.first);
}

/// Send a tiny test print. Same code path for any transport — the connection
/// abstracts it away.
Future<void> _printHello(PrinterInfo info) async {
  final connection = PrinterConnection(info);
  try {
    await connection.connect();
    print('Connected to ${info.portName ?? info.ipAddress}');

    final status = await connection.getStatus();
    print('Status: ${status.toDetailedString()}');

    await connection.sendCommand(TextCommands.printLine('Hello from Flutter!'));
    await connection.sendCommand(TextCommands.printLine(''));
    await connection.sendCommand(TextCommands.feedAndCut());
  } finally {
    await connection.disconnect();
  }
}
