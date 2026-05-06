# Star PRNT Flutter

A Flutter package for Star Micronics thermal printers that supports network discovery and comprehensive printing capabilities using the StarPRNT protocol.

## Features

- 🔍 **Network Discovery**: Automatically discover Star Micronics printers on your local network
- 📝 **Text Printing**: Full support for text formatting, alignment, sizes, and styles
- 🖼️ **Raster Graphics**: Print images and graphics with support for dithering
- 📱 **QR Codes & Barcodes**: Generate and print QR codes, 1D barcodes, and PDF417
- 🔌 **Multi-transport**: Ethernet (TCP), USB, and Bluetooth (Classic/MFi) on iOS and Android
- ⚡ **Command Builder**: Fluent API for building complex print layouts
- ✅ **Status Checking**: Query printer status and paper presence

## Transports

| Transport | Android | iOS | Other platforms |
| --- | --- | --- | --- |
| Ethernet (TCP 9100) | ✅ pure Dart | ✅ pure Dart | ✅ pure Dart |
| USB (USB-B / AOA / USB-C / iOS USB iAP) | ✅ via Star SDK | ✅ via StarIO.framework | ❌ |
| Bluetooth Classic (MFi on iOS) | ✅ via Star SDK | ✅ via StarIO.framework | ❌ |

The Star Micronics native SDK (`com.starmicronics:stario` on Android, `StarIO.framework` on iOS) is bundled with this package and carries the MFi External Accessory protocol registrations (`jp.star-m.starpro` and `jp.star-m.starpro.ext`). Apps using this package inherit MFi access to certified Star printers without their own MFi membership.

## Supported Printers

This package implements the StarPRNT command protocol and should work with most Star Micronics thermal printers, including:

- TSP100 series
- TSP650 series
- TSP700 series
- TSP800 series
- mC-Print2/3
- mPOP
- SM-L series
- And other Star Micronics printers supporting StarPRNT commands

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  star_prnt_flutter:
    git:
      url: https://github.com/jglennrootsnk/star_prnt_flutter.git
```

Then run:

```bash
flutter pub get
```

## Per-platform setup (USB & Bluetooth)

Skip this section if you only need Ethernet (TCP). USB and Bluetooth require small additions to the host app.

### iOS

Add the following to `ios/Runner/Info.plist`. The MFi protocol strings are required — Apple will not load them from a plugin's plist, only from the host app's:

```xml
<key>UISupportedExternalAccessoryProtocols</key>
<array>
  <string>jp.star-m.starpro</string>
  <string>jp.star-m.starpro.ext</string>
</array>
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app uses Bluetooth to communicate with Star printers.</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app uses Bluetooth to communicate with Star printers.</string>
<key>NSLocalNetworkUsageDescription</key>
<string>This app discovers Star printers on the local network.</string>
```

**iOS Bluetooth pairing** must happen in the iOS *Settings → Bluetooth* screen first. Apple does not allow third-party apps to initiate MFi Bluetooth pairing programmatically. Once a Star printer is paired, this package finds it via discovery automatically.

**iOS Simulator on Apple Silicon** requires Rosetta — Star's `StarIO.framework` is a fat binary without separate `arm64-simulator` slices, so the simulator must run in x86_64 mode. On a real device this is irrelevant.

**App Store review** — apps that ship the External Accessory protocols are routinely approved when they actually use a registered Star printer.

### Android

`AndroidManifest.xml` permissions are inherited from this plugin's manifest, but on Android 12+ the *runtime* permissions still have to be requested by the host app:

```dart
// Use the permission_handler package (or equivalent):
await Permission.bluetoothConnect.request();
await Permission.bluetoothScan.request();
```

Set `minSdkVersion 21` (or higher) in `android/app/build.gradle`. USB host mode is automatic — no additional permission is needed.

## Quick Start

### 1. Discover Printers

**Ethernet (pure Dart subnet scan):**

```dart
import 'package:star_prnt_flutter/star_prnt_flutter.dart';

await for (final printer in PrinterDiscovery.discoverLocal()) {
  print('Found printer: ${printer.ipAddress}');
}

// Or specify a subnet
await for (final printer in PrinterDiscovery.discover(subnet: '192.168.1')) {
  print('Found printer: $printer');
}
```

**USB & Bluetooth (Star native SDK):**

```dart
final all = await PrinterDiscovery.discoverNative();
for (final p in all) {
  print('${p.connectionType}: ${p.portName ?? p.ipAddress} (${p.modelName})');
}

// Or filter to a single transport:
final btOnly = await PrinterDiscovery.discoverNative(
  target: NativeDiscoveryTarget.bluetooth,
);
```

### 2. Connect and Print

```dart
// Ethernet (unchanged from previous versions)
final printer = PrinterInfo(ipAddress: '192.168.1.100');
final connection = PrinterConnection(printer);

// USB
final usbPrinter = PrinterInfo.usb(portName: 'USB:TSP100');
final usbConnection = PrinterConnection(usbPrinter);

// Bluetooth
final btPrinter = PrinterInfo.bluetooth(portName: 'BT:00:11:62:00:00:00');
final btConnection = PrinterConnection(btPrinter);

// Or, discovered printers connect with no extra setup:
final discovered = await PrinterDiscovery.discoverNative();
final connection2 = PrinterConnection(discovered.first);

// Connect
await connection.connect();

// Check status
final status = await connection.getStatus();
print('Printer online: ${status.isOnline}');

// Print text
await connection.sendCommand(TextCommands.printLine('Hello World!'));

// Disconnect
await connection.disconnect();
```

### 3. Build a Receipt

```dart
final receipt = TextBuilder()
    .center()
    .bold()
    .doubleSize()
    .line('MY STORE')
    .normalSize()
    .normal()
    .line('123 Main Street')
    .feed()
    .left()
    .line('Receipt #: 12345')
    .feed()
    .line('Item 1           \$10.00')
    .line('Item 2           \$15.50')
    .feed()
    .right()
    .bold()
    .line('TOTAL:          \$25.50')
    .feed(2)
    .center()
    .normal()
    .line('Thank you!')
    .feed(3)
    .cut()
    .build();

await connection.sendCommandSequence(receipt);
```

## Usage Examples

### Text Formatting

```dart
final commands = CommandSequence();

// Alignment
commands.add(TextCommands.setAlignment(1)); // 0=left, 1=center, 2=right

// Text styles
commands.add(TextCommands.enableBold());
commands.add(TextCommands.setUnderline(1)); // 0=off, 1=1-dot, 2=2-dot

// Size
commands.add(TextCommands.setCharacterSize(1, 1)); // width, height (0-7)

// Print
commands.add(TextCommands.printLine('Formatted Text'));

await connection.sendCommandSequence(commands);
```

### Print QR Code

```dart
final qrCommand = GraphicsCommands.printQRCode(
  data: 'https://example.com',
  cellSize: 4,        // 1-8 (default: 3)
  errorCorrection: 1, // 0-3: L,M,Q,H (default: 1=M)
);

await connection.sendCommand(qrCommand);
```

### Print Barcode

```dart
final barcodeCommand = GraphicsCommands.printBarcode(
  data: '123456789',
  type: GraphicsCommands.barcodeTypeCODE39,
  width: 2,   // Module width (2-4)
  height: 60, // Height in dots
  hri: 2,     // Human readable: 0=none, 1=above, 2=below, 3=both
);

await connection.sendCommand(barcodeCommand);
```

### Print Raster Graphics

```dart
// Create a bitmap (true = black, false = white)
final bitmap = List.generate(
  100, // height
  (y) => List.generate(
    384, // width (48mm at 8 dots/mm)
    (x) => (x + y) % 2 == 0, // checkerboard pattern
  ),
);

// Convert to raster data
final rasterData = RasterCommands.bitmapToRaster(bitmap);

// Print
final command = RasterCommands.printRasterGraphics(
  imageData: rasterData,
  width: 384,
  height: 100,
);

await connection.sendCommand(command);
```

### Using RasterImageBuilder

```dart
final imageBuilder = RasterImageBuilder(384, 100);

// Draw shapes
imageBuilder.drawHorizontalLine(0, 0, 383);
imageBuilder.drawVerticalLine(0, 0, 99);
imageBuilder.fillRect(50, 20, 100, 30);

// Build and print
final command = imageBuilder.build();
await connection.sendCommand(command);
```

### Print Grayscale Image with Dithering

```dart
// Assuming you have grayscale image data
Uint8List grayscalePixels = ...; // 0-255 per pixel

// Apply Floyd-Steinberg dithering
final bitmap = RasterCommands.ditherImage(
  imageData: grayscalePixels,
  width: 384,
  height: 200,
);

// Convert and print
final rasterData = RasterCommands.bitmapToRaster(bitmap);
final command = RasterCommands.printRasterGraphics(
  imageData: rasterData,
  width: 384,
  height: 200,
);

await connection.sendCommand(command);
```

## Command Reference

### Text Commands

| Command | Description |
|---------|-------------|
| `initialize()` | Reset printer to default state |
| `printText(text)` | Print text without line feed |
| `printLine(text)` | Print text with line feed |
| `lineFeed([lines])` | Feed paper by lines |
| `setAlignment(n)` | Set alignment (0=left, 1=center, 2=right) |
| `enableBold()` | Enable bold text |
| `disableBold()` | Disable bold text |
| `setUnderline(mode)` | Set underline (0=off, 1=1-dot, 2=2-dot) |
| `setCharacterSize(w, h)` | Set character size (0-7 for each) |
| `enableInvert()` | Enable white-on-black printing |
| `disableInvert()` | Disable inverted printing |
| `cutPaper(mode, lines)` | Cut paper (0=full, 1=partial) |
| `selectFont(n)` | Select font (0=Font A, 1=Font B) |

### Raster Commands

| Command | Description |
|---------|-------------|
| `printRasterGraphics()` | Print bitmap data |
| `bitmapToRaster()` | Convert 2D boolean array to raster |
| `grayscaleToBitmap()` | Convert grayscale to monochrome |
| `ditherImage()` | Apply Floyd-Steinberg dithering |
| `printTestPattern()` | Print a test pattern |

### Graphics Commands

| Command | Description |
|---------|-------------|
| `printQRCode()` | Print QR code |
| `printBarcode()` | Print 1D barcode |
| `printPDF417()` | Print PDF417 2D barcode |
| `printNVGraphics()` | Print stored logo/graphics |
| `printRule()` | Print horizontal line |

## Barcode Types

```dart
GraphicsCommands.barcodeTypeUPCE      // UPC-E
GraphicsCommands.barcodeTypeUPCA      // UPC-A
GraphicsCommands.barcodeTypeJAN8      // JAN-8 (EAN-8)
GraphicsCommands.barcodeTypeJAN13     // JAN-13 (EAN-13)
GraphicsCommands.barcodeTypeCODE39    // CODE39
GraphicsCommands.barcodeTypeITF       // ITF (Interleaved 2 of 5)
GraphicsCommands.barcodeTypeCODE128   // CODE128
GraphicsCommands.barcodeTypeCODE93    // CODE93
GraphicsCommands.barcodeTypeNW7       // NW-7 (CODABAR)
```

## Complete Example

See the [example](example/example.dart) file for a comprehensive demonstration including:
- Printer discovery
- Text formatting
- Raster graphics
- QR codes and barcodes
- Advanced receipt printing

## Troubleshooting

### Printer Not Discovered

1. Ensure the printer is on the same network
2. Check that the printer's IP is in the scanned range
3. Verify firewall settings allow connections on port 9100
4. Try connecting directly with a known IP address

### Print Quality Issues

1. For raster graphics, ensure proper image resolution (8 dots/mm or 203 DPI)
2. Use dithering for grayscale images: `RasterCommands.ditherImage()`
3. Adjust QR code cell size based on scanning distance
4. Check paper quality and printer head cleanliness

### Connection Timeout

1. Increase connection timeout: `connection.connect(timeout: Duration(seconds: 10))`
2. Verify printer IP address is correct
3. Check network connectivity
4. Ensure no firewall blocking the connection

## Protocol Reference

This package implements the StarPRNT command protocol as specified in the Star Micronics documentation. Key commands include:

- Text: ESC-based commands for formatting
- Raster Graphics: `ESC GS S` for bitmap printing
- QR Codes: `ESC GS y S` command set
- Barcodes: `ESC b` for 1D barcodes
- Cut: `ESC d` for paper cutting

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues and feature requests, please visit the [GitHub repository](https://github.com/yourusername/star_prnt_flutter).
