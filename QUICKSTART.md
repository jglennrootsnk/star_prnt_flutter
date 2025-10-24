# Star PRNT Flutter - Quick Start Guide

## Installation

```yaml
# pubspec.yaml
dependencies:
  star_prnt_flutter: ^1.0.0
```

## Basic Usage

### 1. Import the Package

```dart
import 'package:star_prnt_flutter/star_prnt_flutter.dart';
```

### 2. Discover Printers

```dart
// Auto-discover on local network
await for (final printer in PrinterDiscovery.discoverLocal()) {
  print('Found: ${printer.ipAddress}');
}

// Or scan specific subnet
await for (final printer in PrinterDiscovery.discover(
  subnet: '192.168.1',
  startRange: 1,
  endRange: 254,
)) {
  print('Found: $printer');
}
```

### 3. Connect to Printer

```dart
final printer = PrinterInfo(ipAddress: '192.168.1.100');
final connection = PrinterConnection(printer);

await connection.connect();
```

### 4. Simple Print

```dart
// Print text
await connection.sendCommand(
  TextCommands.printLine('Hello World!')
);

// Cut paper
await connection.sendCommand(
  TextCommands.cutPaper()
);
```

### 5. Using TextBuilder

```dart
final receipt = TextBuilder()
    .center()
    .bold()
    .line('RECEIPT')
    .normal()
    .left()
    .line('Item 1: \$10.00')
    .feed(2)
    .cut()
    .build();

await connection.sendCommandSequence(receipt);
```

## Common Patterns

### Print a Receipt

```dart
final receipt = TextBuilder()
    // Header
    .center()
    .bold()
    .doubleSize()
    .line('MY STORE')
    .normalSize()
    .line('123 Main St')
    .feed()
    
    // Items
    .left()
    .normal()
    .line('Qty  Item         Price')
    .line('---  -----------  -----')
    .line(' 1   Coffee       \$3.50')
    .line(' 2   Muffin       \$5.00')
    .feed()
    
    // Total
    .right()
    .bold()
    .line('TOTAL: \$8.50')
    .feed(3) // Line feeds will trigger printing only if the printer is in line mode
    // Otherwise you must change feed to formFeed(), this can be changed in the 
    // settings app
    // Cut
    .cut()
    .build();

await connection.sendCommandSequence(receipt);
```

### Print QR Code

```dart
final commands = CommandSequence();

commands.add(TextCommands.setAlignment(1)); // Center
commands.add(TextCommands.printLine('Scan for details'));
commands.add(GraphicsCommands.printQRCode(
  data: 'https://example.com/order/12345',
  cellSize: 4,
));
commands.add(TextCommands.feedAndCut());

await connection.sendCommandSequence(commands);
```

### Print Barcode

```dart
await connection.sendCommand(
  GraphicsCommands.printBarcode(
    data: '123456789',
    type: GraphicsCommands.barcodeTypeCODE39,
    width: 2,
    height: 60,
    hri: 2, // Print number below barcode
  ),
);
```

### Print an Image

```dart
// Create bitmap (true = black pixel)
final bitmap = List.generate(100, (y) =>
  List.generate(384, (x) => 
    (x + y) % 2 == 0  // Checkerboard
  )
);

// Convert and print
final raster = RasterCommands.bitmapToRaster(bitmap);
await connection.sendCommand(
  RasterCommands.printRasterGraphics(
    imageData: raster,
    width: 384,
    height: 100,
  ),
);
```

### Using RasterImageBuilder
The RasterImageBuilder gives you the ultimate flexibility in layout. It leverages the dart Image package to provide drawing and image rendering functions and then converts the resulting image into bitmap data that can be sent to the printer by calling the build() function. Use this if you want to have full control over the layout, use custom fonts (refer to the Font preparation guide for how to convert TTF to bitmap font zips) and custom images. Look into the examples for ideas on how to use this.
```dart
final img = RasterImageBuilder(384, 100);

// Draw border
img.drawHorizontalLine(0, 0, 383);
img.drawHorizontalLine(99, 0, 383);
img.drawVerticalLine(0, 0, 99);
img.drawVerticalLine(383, 0, 99);

// Fill rectangle
img.fillRect(50, 30, 100, 40);

// Print
await connection.sendCommand(img.build());
```

## Text Formatting Quick Reference

```dart
// Alignment
TextCommands.setAlignment(0)  // Left
TextCommands.setAlignment(1)  // Center
TextCommands.setAlignment(2)  // Right

// Styles
TextCommands.enableBold()
TextCommands.disableBold()
TextCommands.setUnderline(1)  // 0=off, 1=1-dot, 2=2-dot
TextCommands.enableInvert()   // White on black

// Size
TextCommands.setCharacterSize(1, 1)  // 2x width, 2x height
TextCommands.enableDoubleWidth()
TextCommands.enableDoubleHeight()

// Spacing
TextCommands.lineFeed()       // Single line
TextCommands.lineFeed(3)      // Multiple lines
TextCommands.setLineSpacing(dots)

// Cut
TextCommands.cutPaper()
TextCommands.feedAndCut(feedLines: 3)
```

## Error Handling

```dart
try {
  await connection.connect();
  
  // Check printer status
  final status = await connection.getStatus();
  if (!status.isOnline) {
    print('Printer offline');
    return;
  }
  
  if (!status.paperPresent) {
    print('No paper');
    return;
  }
  
  // Print...
  
} catch (e) {
  print('Error: $e');
} finally {
  await connection.disconnect();
}
```

## Disconnect

```dart
await connection.disconnect();
```

## Tips

1. **Paper Width**: Standard Star printers are 80mm (576 dots at 8 dots/mm)
2. **Image Width**: Use 384-512 dots for 80mm paper (leaves margins)
3. **Dithering**: Use `RasterCommands.ditherImage()` for photos
4. **Network**: Printers typically use port 9100
5. **Testing**: Use `RasterCommands.printTestPattern()` to verify connectivity

## Example Output Sizes

For 80mm paper at 8 dots/mm (203 DPI):
- Full width: 576 dots
- Safe width (with margins): 384-512 dots
- Character width: 12 dots (Font A), 9 dots (Font B)
- Standard characters per line: 48 (Font A), 64 (Font B)

## Complete Example

```dart
Future<void> printReceipt(String orderNumber) async {
  final printer = PrinterInfo(ipAddress: '192.168.1.100');
  final connection = PrinterConnection(printer);
  
  try {
    await connection.connect();
    
    final receipt = TextBuilder()
        .center()
        .bold()
        .line('ORDER RECEIPT')
        .normal()
        .line('Order: $orderNumber')
        .feed()
        .left()
        .line('Thank you!')
        .feed(2)
        .center()
        .build();
    
    // Add QR code
    receipt.add(GraphicsCommands.printQRCode(
      data: 'https://orders.com/$orderNumber',
    ));
    
    receipt.add(TextCommands.feedAndCut());
    
    await connection.sendCommandSequence(receipt);
    
  } finally {
    await connection.disconnect();
  }
}
```
