import 'dart:io';
import 'package:star_prnt_flutter/star_prnt_flutter.dart';
import 'src/helpers/bowl_label_generator.dart';

/// Entry point for testing Star PRNT Flutter functionality
/// 
/// This demonstrates all the key features from the quickstart guide:
/// - Printer discovery
/// - Connection management
/// - Text printing with formatting
/// - Graphics commands (QR codes, barcodes)
/// - Raster graphics
/// - Error handling
Future<void> main() async {
  print('=== Star PRNT Flutter Test ===\n');

  try {
    // Test 1: Printer Discovery
    // await testPrinterDiscovery();

    // Test 2: Manual Connection Test
    final printerIp = '10.0.0.166'; // await promptForPrinterIp() ?? 
    await testPrinterConnection(printerIp);
    await testBasicPrinting(printerIp);
    await Future.delayed(const Duration(seconds: 2));
    await testFormattedReceipt(printerIp);
    await Future.delayed(const Duration(seconds: 2));
    await testGraphicsCommands(printerIp);
    await Future.delayed(const Duration(seconds: 2));
    await testRasterGraphics(printerIp);
    await Future.delayed(const Duration(seconds: 2));
    await testLabelGeneration(printerIp, mock: false);

    print('\n=== Test Complete ===');
  } catch (e, stackTrace) {
    print('Error during testing: $e');
    print('Stack trace: $stackTrace');
  } finally {
    // Force exit after a short delay to ensure all async operations complete
    await Future.delayed(const Duration(milliseconds: 100));
    exit(0);
  }
}

/// Test 1: Discover printers on the network
Future<void> testPrinterDiscovery() async {
  print('--- Test 1: Printer Discovery ---');
  
  try {
    // Try to discover printers on local network
    print('Discovering printers on local network...');
    
    var foundPrinters = <PrinterInfo>[];
    
    // Set a timeout for discovery
    await for (final printer in PrinterDiscovery.discoverLocal()
        .timeout(const Duration(seconds: 10))) {
      foundPrinters.add(printer);
      print('Found printer: ${printer.ipAddress}:${printer.port}');
    }
    
    if (foundPrinters.isEmpty) {
      print('No printers found on local network');
      
      // Try specific subnet if local discovery fails
      print('Trying common subnet 192.168.1.x...');
      await for (final printer in PrinterDiscovery.discover(
        subnet: '192.168.1',
        startRange: 1,
        endRange: 10, // Limit range for faster testing
      ).timeout(const Duration(seconds: 5))) {
        foundPrinters.add(printer);
        print('Found printer: ${printer.ipAddress}:${printer.port}');
      }
    }
    
    print('Discovery complete. Found ${foundPrinters.length} printer(s)\n');
  } catch (e) {
    print('Discovery error: $e\n');
  }
}

/// Test 2: Test basic printer connection
Future<void> testPrinterConnection(String ipAddress) async {
  print('--- Test 2: Printer Connection ---');
  
  final printer = PrinterInfo(ipAddress: ipAddress);
  final connection = PrinterConnection(printer);
  
  try {
    print('Connecting to printer at $ipAddress...');
    await connection.connect();
    print('✓ Connected successfully');
    
    // Test status
    print('Checking printer status...');
    final status = await connection.getStatus();
    print('Status: $status');
    
    if (!status.isOnline) {
      print('⚠️  Printer appears to be offline');
    }
    
    if (!status.paperPresent) {
      print('⚠️  No paper detected');
    }
    
  } catch (e) {
    print('❌ Connection failed: $e');
    throw e;
  } finally {
    await connection.disconnect();
    print('Disconnected from printer\n');
  }
}

/// Test 3: Basic text printing
Future<void> testBasicPrinting(String ipAddress) async {
  print('--- Test 3: Basic Text Printing ---');
  
  final printer = PrinterInfo(ipAddress: ipAddress);
  final connection = PrinterConnection(printer);
  
  try {
    await connection.connect();
    
    // Initialize printer
    await connection.sendCommand(TextCommands.initialize());
    
    // Simple text
    await connection.sendCommand(TextCommands.printLine('Hello World!'));
    await connection.sendCommand(TextCommands.printLine('This is a test print.'));
    
    // Test different alignments
    await connection.sendCommand(TextCommands.setAlignment(1)); // Center
    await connection.sendCommand(TextCommands.printLine('--- CENTERED TEXT ---'));
    
    await connection.sendCommand(TextCommands.setAlignment(2)); // Right
    await connection.sendCommand(TextCommands.printLine('RIGHT ALIGNED'));
    
    await connection.sendCommand(TextCommands.setAlignment(0)); // Left
    await connection.sendCommand(TextCommands.printLine('Back to left alignment'));
    
    // Test formatting
    await connection.sendCommand(TextCommands.enableBold());
    await connection.sendCommand(TextCommands.printLine('BOLD TEXT'));
    await connection.sendCommand(TextCommands.disableBold());
    
    await connection.sendCommand(TextCommands.setUnderline(1));
    await connection.sendCommand(TextCommands.printLine('Underlined text'));
    await connection.sendCommand(TextCommands.setUnderline(0));
    
    // Feed and cut
    await connection.sendCommand(TextCommands.lineFeed(5));
    await connection.sendCommand(TextCommands.cutPaper());
    
    print('✓ Basic printing test completed');
    
  } catch (e) {
    print('❌ Basic printing failed: $e');
  } finally {
    // Ensure connection is fully closed
    try {
      await connection.disconnect();
      // Give socket time to fully close
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      print('Warning: Error during disconnect: $e');
    }
  }
  
  print('');
}

/// Test 4: Print a formatted receipt using TextBuilder pattern
Future<void> testFormattedReceipt(String ipAddress) async {
  print('--- Test 4: Formatted Receipt ---');
  
  final printer = PrinterInfo(ipAddress: ipAddress);
  final connection = PrinterConnection(printer);
  
  try {
    await connection.connect();
    
    // Create receipt using TextBuilder
    final receipt = TextBuilder()
        // Header
        .center()
        .bold()
        .doubleSize()
        .line('FLUTTER STORE')
        .normalSize()
        .normal()
        .line('123 Test Street')
        .line('Flutter City, FC 12345')
        .line('Tel: (555) 123-4567')
        .feed()
        
        // Receipt details
        .left()
        .line('Receipt #: FL-2024-001')
        .line('Date: ${DateTime.now().toString().substring(0, 19)}')
        .line('Clerk: Test User')
        .feed()
        
        // Items
        .line('Qty  Item             Price')
        .line('================================')
        .line(' 2   Flutter Course   \$49.99')
        .line(' 1   Dart Book        \$29.99')
        .line(' 3   Coffee           \$15.00')
        .line('--------------------------------')
        
        // Totals
        .right()
        .line('Subtotal: \$94.98')
        .line('Tax:       \$8.55')
        .bold()
        .line('TOTAL:   \$103.53')
        .normal()
        .feed()
        
        // Footer
        .center()
        .line('Thank you for your purchase!')
        .line('Please come again')
        .feed(3)
        
        // Cut paper
        .cut()
        .build();
    
    // Send the entire receipt
    await connection.sendCommandSequence(receipt);
    
    print('✓ Formatted receipt printed');
    
  } catch (e) {
    print('❌ Receipt printing failed: $e');
  } finally {
    await connection.disconnect();
  }
  
  print('');
}

/// Test 5: Graphics commands (QR codes and barcodes)
Future<void> testGraphicsCommands(String ipAddress) async {
  print('--- Test 5: Graphics Commands ---');
  
  final printer = PrinterInfo(ipAddress: ipAddress);
  final connection = PrinterConnection(printer);
  
  try {
    await connection.connect();
    
    final graphics = CommandSequence();
    
    graphics.add(TextCommands.initialize());
    graphics.add(TextCommands.setAlignment(1)); // Center
    graphics.add(TextCommands.printLine('=== GRAPHICS TEST ==='));
    graphics.add(TextCommands.lineFeed());
    
    // QR Code
    graphics.add(TextCommands.printLine('QR Code:'));
    graphics.add(GraphicsCommands.printQRCode(
      data: 'https://flutter.dev',
      cellSize: 4,
    ));
    graphics.add(TextCommands.lineFeed());
    
    // Barcode
    graphics.add(TextCommands.printLine('Barcode:'));
    graphics.add(GraphicsCommands.printBarcode(
      data: '123456789012',
      type: GraphicsCommands.barcodeTypeCODE128,
      width: 2,
      height: 60,
      hri: 2, // Print number below barcode
    ));
    graphics.add(TextCommands.lineFeed(2));
    
    // Test pattern
    graphics.add(TextCommands.printLine('Test Pattern:'));
    graphics.add(RasterCommands.printTestPattern());
    graphics.add(TextCommands.lineFeed(5));
    
    graphics.add(TextCommands.cutPaper());
    
    await connection.sendCommandSequence(graphics);
    
    print('✓ Graphics commands completed');
    
  } catch (e) {
    print('❌ Graphics commands failed: $e');
  } finally {
    await connection.disconnect();
  }
  
  print('');
}

/// Test 6: Raster graphics
Future<void> testRasterGraphics(String ipAddress) async {
  print('--- Test 6: Raster Graphics ---');
  
  final printer = PrinterInfo(ipAddress: ipAddress);
  final connection = PrinterConnection(printer);
  
  try {
    await connection.connect();
    
    final raster = CommandSequence();
    
    raster.add(TextCommands.initialize());
    raster.add(TextCommands.setAlignment(1)); // Center
    raster.add(TextCommands.printLine('=== RASTER TEST ==='));
    raster.add(TextCommands.lineFeed());
    
    // Create a simple pattern bitmap (checkerboard)
    final width = 384; // Safe width for 80mm paper
    final height = 100;
    
    // Create bitmap (true = black pixel, false = white pixel)
    final bitmap = List.generate(height, (y) =>
      List.generate(width, (x) => 
        ((x ~/ 8) + (y ~/ 8)) % 2 == 0  // Checkerboard pattern
      )
    );
    
    // Convert bitmap to raster data and print
    final rasterData = RasterCommands.bitmapToRaster(bitmap);
    raster.add(RasterCommands.printRasterGraphics(
      imageData: rasterData,
      width: width,
      height: height,
    ));
    
    raster.add(TextCommands.lineFeed());
    raster.add(TextCommands.printLine('Checkerboard Pattern'));
    raster.add(TextCommands.lineFeed(2));
    
    // Test RasterImageBuilder
    final img = RasterImageBuilder(384, 50);
    
    // Draw border
    img.drawHorizontalLine(0, 0, 383);
    img.drawHorizontalLine(49, 0, 383);
    img.drawVerticalLine(0, 0, 49);
    img.drawVerticalLine(383, 0, 49);
    
    // Fill some rectangles
    img.fillRect(50, 10, 100, 30);
    img.fillRect(200, 10, 100, 30);
    
    raster.add(img.build());
    raster.add(TextCommands.lineFeed());
    raster.add(TextCommands.printLine('Custom Graphics'));
    raster.add(TextCommands.lineFeed(5));
    
    raster.add(TextCommands.cutPaper());
    
    await connection.sendCommandSequence(raster);
    
    print('✓ Raster graphics completed');
    
  } catch (e) {
    print('❌ Raster graphics failed: $e');
  } finally {
    await connection.disconnect();
  }
  
  print('');
}

/// Test 7: Label generation using bitmap fonts
Future<void> testLabelGeneration(String ipAddress, {bool mock = false}) async {
  print('--- Test 7: Label Generation ---');
  final printer = PrinterInfo(ipAddress: ipAddress);
  final connection = PrinterConnection(printer);
  
  try {
    await connection.connect();
    
    print('Generating food order label...');
    
    // Generate the label using the LabelGenerator helper
    // Note: Replace placeholder paths with actual icon/logo files
    final labelCommand = await BowlLabelGenerator.generateLabel(
      // Use the actual Quicksand fonts from ./fonts directory
      font18Path: './fonts/Quicksand-Regular-18px.zip',
      font24Path: './fonts/Quicksand-Regular-24px.zip',
      font32Path: './fonts/Quicksand-Medium-32px.zip',
      font48Path: './fonts/Quicksand-Bold-48px.zip',
      font72Path: './fonts/Quicksand-Medium-72px.zip',
      
      // Sample food order data
      customerName: 'Colinian Glennerson',
      platformIconPath: './icons/doordash-icon.png', // Update with actual path if available
      itemIndex: '(2 of 4)',
      itemName: 'El Jefe Bowl',
      itemIngredients: 'Brown Rice (P), Kale (S), Avocado, -Blk Beans, +Broccoli, '
          'Corn, +Cheddar, -Tabasco, -Feta, -Lime, -Pita, -Onions, '
          '+Sweets, -Tabasco, -Lime, Chicken, -Cil Lime, +Pesto',
      orderNumber: '9678039',
      eatByDate: '10/11/2025',
      orderType: 'Delivery',
      logoPath: './icons/logo.png', // Update with actual path if available
      mock: mock, // Pass through mock parameter
    );
    if (!mock) {
      // Send the label to printer
      await connection.sendCommand(labelCommand);
      
      // Add some space after the label
      await connection.sendCommand(TextCommands.lineFeed(5));

      // cut the label
      await connection.sendCommand(TextCommands.cutPaper());
    }
    
    print('✓ Label printed successfully');
    
  } catch (e) {
    print('❌ Label generation failed: $e');
    print('Note: Make sure icon files exist at ./icons/doordash.png and ./icons/logo.png');
  } finally {
    await connection.disconnect();
  }
  
  print('');
}

/// Helper function to prompt user for printer IP address
Future<String?> promptForPrinterIp() async {
  print('\nTo test printing functionality:');
  print('Enter printer IP address (or press Enter to skip printer tests):');
  stdout.write('IP address: ');
  final input = stdin.readLineSync();
  
  if (input == null || input.trim().isEmpty) {
    print('Skipping printer connection tests...');
    return null;
  }
  
  final ip = input.trim();
  
  // Basic IP validation
  final parts = ip.split('.');
  if (parts.length != 4) {
    print('Invalid IP address format. Please use format: xxx.xxx.xxx.xxx');
    return null;
  }
  
  try {
    for (final part in parts) {
      final num = int.parse(part);
      if (num < 0 || num > 255) {
        throw FormatException('Invalid IP range');
      }
    }
  } catch (e) {
    print('Invalid IP address format. Please use format: xxx.xxx.xxx.xxx');
    return null;
  }
  
  return ip;
}

/// Example function showing complete receipt printing workflow
Future<void> printExampleReceipt(String orderNumber, String ipAddress) async {
  final printer = PrinterInfo(ipAddress: ipAddress);
  final connection = PrinterConnection(printer);
  
  try {
    await connection.connect();
    
    // Check status first
    final status = await connection.getStatus();
    if (!status.isOnline) {
      throw Exception('Printer offline');
    }
    
    if (!status.paperPresent) {
      throw Exception('No paper');
    }
    
    // Build receipt
    final receipt = CommandSequence();
    
    receipt.add(TextCommands.initialize());
    receipt.add(TextCommands.setAlignment(1));
    receipt.add(TextCommands.enableBold());
    receipt.add(TextCommands.printLine('ORDER RECEIPT'));
    receipt.add(TextCommands.disableBold());
    receipt.add(TextCommands.printLine('Order: $orderNumber'));
    receipt.add(TextCommands.lineFeed());
    receipt.add(TextCommands.setAlignment(0));
    receipt.add(TextCommands.printLine('Thank you for your order!'));
    receipt.add(TextCommands.lineFeed(2));
    receipt.add(TextCommands.setAlignment(1));
    
    // Add QR code with order URL
    receipt.add(GraphicsCommands.printQRCode(
      data: 'https://orders.example.com/$orderNumber',
    ));
    
    receipt.add(TextCommands.lineFeed());
    receipt.add(TextCommands.printLine('Scan for order details'));
    receipt.add(TextCommands.feedAndCut(feedLines: 3));
    
    await connection.sendCommandSequence(receipt);
    
  } finally {
    await connection.disconnect();
  }
}