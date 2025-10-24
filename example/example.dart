import 'package:star_prnt_flutter/star_prnt_flutter.dart';

Future<void> main() async {
  // Example 1: Discover printers on the network
  await discoverPrinters();

  // Example 2: Print text
  await printTextExample();

  // Example 3: Print raster graphics
  await printRasterExample();

  // Example 4: Print QR code and barcode
  await printGraphicsExample();
}

/// Example: Discover printers on the local network
Future<void> discoverPrinters() async {
  print('Discovering printers on the network...');

  try {
    // Discover printers on the local network
    await for (final printer in PrinterDiscovery.discoverLocal()) {
      print('Found printer: $printer');
    }

    // Or discover on a specific subnet
    await for (final printer in PrinterDiscovery.discover(
      subnet: '192.168.1',
      startRange: 1,
      endRange: 254,
    )) {
      print('Found printer: $printer');
    }

    // Check if a specific printer is online
    final isOnline = await PrinterDiscovery.isPrinterOnline('192.168.1.100');
    print('Printer is online: $isOnline');
  } catch (e) {
    print('Error discovering printers: $e');
  }
}

/// Example: Print text with various formatting
Future<void> printTextExample() async {
  final printer = PrinterInfo(ipAddress: '192.168.1.100');
  final connection = PrinterConnection(printer);

  try {
    // Connect to printer
    await connection.connect();
    print('Connected to printer');

    // Check printer status
    final status = await connection.getStatus();
    print('Printer status: $status');

    // Build a receipt using TextBuilder
    final receipt = TextBuilder()
        .center()
        .bold()
        .doubleSize()
        .line('MY STORE')
        .normalSize()
        .normal()
        .line('123 Main Street')
        .line('City, ST 12345')
        .feed()
        .left()
        .line('Date: 2025-10-23')
        .line('Receipt #: 12345')
        .feed()
        .bold()
        .line('ITEMS:')
        .normal()
        .line('Item 1           \$10.00')
        .line('Item 2           \$15.50')
        .line('Item 3            \$5.25')
        .feed()
        .right()
        .bold()
        .line('TOTAL:          \$30.75')
        .feed(2)
        .center()
        .normal()
        .line('Thank you for your purchase!')
        .feed(3)
        .cut()
        .build();

    // Send to printer
    await connection.sendCommandSequence(receipt);
    print('Receipt printed successfully');

    // Disconnect
    await connection.disconnect();
  } catch (e) {
    print('Error printing: $e');
  }
}

/// Example: Print raster graphics
Future<void> printRasterExample() async {
  final printer = PrinterInfo(ipAddress: '192.168.1.100');
  final connection = PrinterConnection(printer);

  try {
    await connection.connect();

    // Create a simple graphic using RasterImageBuilder
    final imageBuilder = RasterImageBuilder(384, 100); // 384 dots = 48mm at 8 dots/mm

    // Draw a border
    imageBuilder.drawHorizontalLine(0, 0, 383);
    imageBuilder.drawHorizontalLine(99, 0, 383);
    imageBuilder.drawVerticalLine(0, 0, 99);
    imageBuilder.drawVerticalLine(383, 0, 99);

    // Draw some filled rectangles
    imageBuilder.fillRect(50, 20, 100, 30);
    imageBuilder.fillRect(200, 40, 80, 40);

    // Build and print
    final rasterCommand = imageBuilder.build();
    await connection.sendCommand(rasterCommand);

    // Print a test pattern
    await connection.sendCommand(RasterCommands.printTestPattern());

    await connection.disconnect();
    print('Graphics printed successfully');
  } catch (e) {
    print('Error printing graphics: $e');
  }
}

/// Example: Print QR code and barcode
Future<void> printGraphicsExample() async {
  final printer = PrinterInfo(ipAddress: '192.168.1.100');
  final connection = PrinterConnection(printer);

  try {
    await connection.connect();

    final commands = CommandSequence();

    // Add text
    commands.add(TextCommands.initialize());
    commands.add(TextCommands.setAlignment(1)); // Center
    commands.add(TextCommands.printLine('Scan QR Code'));
    commands.add(TextCommands.lineFeed());

    // Add QR code
    commands.add(GraphicsCommands.printQRCode(
      data: 'https://example.com/product/12345',
      cellSize: 4,
      errorCorrection: 1,
    ));

    commands.add(TextCommands.lineFeed(2));

    // Add barcode
    commands.add(TextCommands.printLine('Product Code'));
    commands.add(GraphicsCommands.printBarcode(
      data: '123456789',
      type: GraphicsCommands.barcodeTypeCODE39,
      width: 2,
      height: 60,
      hri: 2, // Print human-readable text below
    ));

    commands.add(TextCommands.lineFeed(3));
    commands.add(TextCommands.cutPaper(feedLines: 3));

    // Send all commands
    await connection.sendCommandSequence(commands);

    await connection.disconnect();
    print('QR code and barcode printed successfully');
  } catch (e) {
    print('Error printing graphics: $e');
  }
}

/// Example: Advanced receipt with mixed content
Future<void> printAdvancedReceipt() async {
  final printer = PrinterInfo(ipAddress: '192.168.1.100');
  final connection = PrinterConnection(printer);

  try {
    await connection.connect();

    final commands = CommandSequence();

    // Initialize
    commands.add(TextCommands.initialize());

    // Header with logo (if you have a stored logo)
    // commands.add(GraphicsCommands.printNVGraphics(keyCode: 1));

    // Store name
    commands.add(TextCommands.setAlignment(1));
    commands.add(TextCommands.enableBold());
    commands.add(TextCommands.setCharacterSize(1, 1));
    commands.add(TextCommands.printLine('COFFEE SHOP'));
    commands.add(TextCommands.disableBold());
    commands.add(TextCommands.setCharacterSize(0, 0));
    commands.add(TextCommands.printLine('123 Main St, City 12345'));
    commands.add(TextCommands.printLine('Tel: (555) 123-4567'));
    commands.add(TextCommands.lineFeed());

    // Horizontal rule
    commands.add(GraphicsCommands.printRule(width: 32));

    // Items
    commands.add(TextCommands.setAlignment(0)); // Left align
    commands.add(TextCommands.printLine('Date: 2025-10-23 14:30'));
    commands.add(TextCommands.printLine('Order #: 12345'));
    commands.add(TextCommands.lineFeed());
    commands.add(GraphicsCommands.printRule(width: 32));
    
    commands.add(TextCommands.enableBold());
    commands.add(TextCommands.printLine('QTY  ITEM             PRICE'));
    commands.add(TextCommands.disableBold());
    commands.add(GraphicsCommands.printRule(width: 32));

    commands.add(TextCommands.printLine('1    Cappuccino      \$4.50'));
    commands.add(TextCommands.printLine('2    Croissant       \$6.00'));
    commands.add(TextCommands.printLine('1    Muffin          \$3.50'));
    commands.add(TextCommands.lineFeed());

    commands.add(GraphicsCommands.printRule(width: 32));
    commands.add(TextCommands.setAlignment(2)); // Right align
    commands.add(TextCommands.enableBold());
    commands.add(TextCommands.printLine('Subtotal:     \$14.00'));
    commands.add(TextCommands.printLine('Tax (8.5%):    \$1.19'));
    commands.add(TextCommands.setCharacterSize(1, 0));
    commands.add(TextCommands.printLine('TOTAL:        \$15.19'));
    commands.add(TextCommands.setCharacterSize(0, 0));
    commands.add(TextCommands.disableBold());
    commands.add(TextCommands.lineFeed());

    // QR code for receipt
    commands.add(TextCommands.setAlignment(1));
    commands.add(TextCommands.printLine('Scan for digital receipt'));
    commands.add(GraphicsCommands.printQRCode(
      data: 'https://myshop.com/receipt/12345',
      cellSize: 3,
    ));

    // Footer
    commands.add(TextCommands.lineFeed(2));
    commands.add(TextCommands.printLine('Thank you!'));
    commands.add(TextCommands.printLine('Visit us again soon'));

    // Cut paper
    commands.add(TextCommands.feedAndCut(feedLines: 4));

    // Send everything
    await connection.sendCommandSequence(commands);

    await connection.disconnect();
    print('Advanced receipt printed successfully');
  } catch (e) {
    print('Error printing: $e');
  }
}
