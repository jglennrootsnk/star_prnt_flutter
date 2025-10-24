import 'package:star_prnt_flutter/star_prnt_flutter.dart';

/// Comprehensive demo of RasterImageBuilder features
Future<void> main() async {
  print('=== RasterImageBuilder Enhanced Features Demo ===\n');
  
  // Demo 1: Basic shapes with rounded corners
  await demoRoundedShapes();
  
  // Demo 2: Circles and lines
  await demoCirclesAndLines();
  
  // Demo 3: Image rotation
  await demoRotation();
  
  // Demo 4: Text rendering with real fonts
  await demoTextRendering();
  
  // Demo 5: Image composition
  await demoImageComposition();
  
  // Demo 6: Color inversion
  await demoInversion();
  
  // Demo 7: Complete receipt with fonts
  await demoCompleteReceipt();
  
  print('\n=== Demo Complete ===');
  print('To print these demos, call printDemo(printerIp) with your printer IP');
}

/// Font paths helper
class Fonts {
  static const basePath = 'example';
  
  static String quicksandRegular(int size) => '$basePath/Quicksand-Regular-${size}px.zip';
  static String quicksandMedium(int size) => '$basePath/Quicksand-Medium-${size}px.zip';
  static String quicksandBold(int size) => '$basePath/Quicksand-Bold-${size}px.zip';
}

/// Demo 1: Rounded rectangles and shapes
Future<void> demoRoundedShapes() async {
  print('Demo 1: Rounded Shapes');
  
  final img = RasterImageBuilder(384, 200);
  
  // Title
  img.drawLine(0, 10, 383, 10, thickness: 2);
  
  // Filled rectangle with uniform rounded corners
  img.fillRect(20, 30, 100, 60, radius: 10);
  
  // Outlined rectangle with different corner radii
  img.drawRect(
    140, 30, 100, 60,
    thickness: 2,
    topLeft: 20,
    topRight: 5,
    bottomLeft: 5,
    bottomRight: 20,
  );
  
  // Mixed: filled with custom radii
  img.fillRect(
    260, 30, 100, 60,
    topLeft: 0,
    topRight: 15,
    bottomLeft: 15,
    bottomRight: 0,
  );
  
  // Bottom row: various radius combinations
  img.fillRect(20, 110, 80, 50, topLeft: 25, topRight: 25);
  img.fillRect(120, 110, 80, 50, bottomLeft: 25, bottomRight: 25);
  img.fillRect(220, 110, 80, 50, topLeft: 15, bottomRight: 15);
  
  print('✓ Created rounded shapes demo (384x200)');
  await printRasterImage(img, '10.0.0.166');
}

/// Demo 2: Circles and various line types
Future<void> demoCirclesAndLines() async {
  print('Demo 2: Circles and Lines');
  
  final img = RasterImageBuilder(384, 250);
  
  // Grid of circles
  for (var i = 0; i < 3; i++) {
    for (var j = 0; j < 4; j++) {
      final cx = 50 + j * 90;
      final cy = 40 + i * 70;
      
      if ((i + j) % 2 == 0) {
        img.fillCircle(cx, cy, 25);
      } else {
        img.drawCircle(cx, cy, 25, thickness: 2);
      }
    }
  }
  
  // Diagonal lines
  img.drawLine(0, 230, 383, 200, thickness: 3);
  img.drawLine(383, 230, 0, 200, thickness: 3);
  
  print('✓ Created circles and lines demo (384x250)');
  await printRasterImage(img, '10.0.0.166');
}

/// Demo 3: Image rotation
Future<void> demoRotation() async {
  print('Demo 3: Rotation');
  
  // Create images with different rotations
  for (final rotation in [0, 90, 180, 270]) {
    final img = RasterImageBuilder(200, 100, rotation: rotation);
    
    // Draw an arrow to show orientation
    img.fillRect(10, 40, 100, 20); // Shaft
    img.fillRect(90, 20, 40, 60);  // Head (wider)
    img.fillRect(110, 10, 20, 80); // Head point
    
    // Add corner markers
    img.fillCircle(10, 10, 5);
    img.fillCircle(190, 10, 5);
    img.fillCircle(10, 90, 5);
    img.fillCircle(190, 90, 5);
    
    print('✓ Created $rotation° rotated image (200x100)');
    await printRasterImage(img, '10.0.0.166');
  }
}

/// Demo 4: Text rendering with bitmap fonts
Future<void> demoTextRendering() async {
  print('Demo 4: Text Rendering with Bitmap Fonts');
  
  final img = RasterImageBuilder(384, 300);
  
  // Title
  img.drawLine(0, 5, 383, 5, thickness: 2);
  
  try {
    // Different font sizes
    await img.drawText(
      'Quicksand Regular 18px',
      x: 10,
      y: 20,
      fontPath: Fonts.quicksandRegular(18),
      size: 18,
    );
    
    await img.drawText(
      'Quicksand Regular 24px',
      x: 10,
      y: 50,
      fontPath: Fonts.quicksandRegular(24),
      size: 24,
    );
    
    await img.drawText(
      'Quicksand Medium 24px',
      x: 10,
      y: 85,
      fontPath: Fonts.quicksandMedium(24),
      size: 24,
    );
    
    await img.drawText(
      'Bold 18px',
      x: 10,
      y: 120,
      fontPath: Fonts.quicksandBold(18),
      size: 18,
    );
    
    await img.drawText(
      'Bold 24px',
      x: 10,
      y: 150,
      fontPath: Fonts.quicksandBold(24),
      size: 24,
    );
    
    await img.drawText(
      'Bold 32px',
      x: 10,
      y: 185,
      fontPath: Fonts.quicksandBold(32),
      size: 32,
    );
    
    await img.drawText(
      'LARGE 48px',
      x: 10,
      y: 230,
      fontPath: Fonts.quicksandBold(48),
      size: 48,
    );
    
    print('✓ Created text rendering demo with 7 different fonts (384x300)');
    await printRasterImage(img, '10.0.0.166');
  } catch (e) {
    print('⚠️  Error rendering text: $e');
    print('   (Font loading may need adjustment for your environment)');
  }
}

/// Demo 5: Image composition
Future<void> demoImageComposition() async {
  print('Demo 5: Image Composition');
  
  final mainImg = RasterImageBuilder(384, 200);
  
  // Draw background pattern
  for (var i = 0; i < 20; i++) {
    mainImg.drawLine(0, i * 10, 383, i * 10, color: 200);
  }
  
  // Create smaller images to composite
  final stamp1 = RasterImageBuilder(60, 60);
  stamp1.fillCircle(30, 30, 25);
  stamp1.fillRect(20, 20, 20, 20, color: 255); // White square in center
  
  final stamp2 = RasterImageBuilder(80, 80);
  stamp2.fillRect(10, 10, 60, 60, radius: 15);
  stamp2.drawLine(10, 40, 70, 40, thickness: 3, color: 255);
  stamp2.drawLine(40, 10, 40, 70, thickness: 3, color: 255);
  
  // Composite stamps onto main image
  mainImg.drawImage(stamp1, 50, 50);
  mainImg.drawImage(stamp2, 150, 50);
  mainImg.drawImage(stamp1, 260, 50);
  
  print('✓ Created image composition demo (384x200)');
  await printRasterImage(mainImg, '10.0.0.166');
}

/// Demo 6: Color inversion
Future<void> demoInversion() async {
  print('Demo 6: Color Inversion');
  
  final img = RasterImageBuilder(384, 150);
  
  // Draw some shapes
  img.fillRect(20, 20, 100, 60);
  img.fillCircle(180, 50, 30);
  img.drawRect(240, 20, 100, 60, thickness: 3);
  
  // Invert specific regions
  img.invert(x: 20, y: 20, w: 100, h: 60);  // Invert the rectangle
  img.invert(x: 240, y: 20, w: 100, h: 60); // Invert the outline rect
  
  // Draw more after inversion
  img.drawLine(0, 100, 383, 100, thickness: 2);
  img.fillRect(150, 110, 84, 30);
  
  // Invert bottom section
  img.invert(y: 100);
  
  print('✓ Created inversion demo (384x150)');
  await printRasterImage(img, '10.0.0.166');
}

/// Demo 7: Complete receipt with fonts and graphics
Future<void> demoCompleteReceipt() async {
  print('Demo 7: Complete Receipt with Fonts');
  
  final img = RasterImageBuilder(384, 600);
  
  try {
    // Header with large bold title
    await img.drawText(
      'COFFEE SHOP',
      x: 80,
      y: 10,
      fontPath: Fonts.quicksandBold(48),
      size: 48,
    );
    
    // Subtitle
    await img.drawText(
      '123 Main Street, City',
      x: 90,
      y: 65,
      fontPath: Fonts.quicksandRegular(18),
      size: 18,
    );
    
    // Decorative line
    img.drawLine(20, 95, 364, 95, thickness: 2);
    
    // Receipt details
    await img.drawText(
      'Receipt #: 2024-1001',
      x: 20,
      y: 110,
      fontPath: Fonts.quicksandRegular(18),
      size: 18,
    );
    
    await img.drawText(
      'Date: Oct 23, 2025 14:30',
      x: 20,
      y: 135,
      fontPath: Fonts.quicksandRegular(18),
      size: 18,
    );
    
    // Another line
    img.drawLine(20, 160, 364, 160, thickness: 1);
    
    // Items header
    await img.drawText(
      'ITEMS',
      x: 20,
      y: 175,
      fontPath: Fonts.quicksandBold(24),
      size: 24,
    );
    
    // Item 1
    await img.drawText(
      'Cappuccino - Grande',
      x: 20,
      y: 210,
      fontPath: Fonts.quicksandRegular(18),
      size: 18,
    );
    await img.drawText(
      '\$4.50',
      x: 320,
      y: 210,
      fontPath: Fonts.quicksandRegular(18),
      size: 18,
    );
    
    // Item 2
    await img.drawText(
      'Croissant x2',
      x: 20,
      y: 235,
      fontPath: Fonts.quicksandRegular(18),
      size: 18,
    );
    await img.drawText(
      '\$6.00',
      x: 320,
      y: 235,
      fontPath: Fonts.quicksandRegular(18),
      size: 18,
    );
    
    // Item 3
    await img.drawText(
      'Muffin',
      x: 20,
      y: 260,
      fontPath: Fonts.quicksandRegular(18),
      size: 18,
    );
    await img.drawText(
      '\$3.50',
      x: 320,
      y: 260,
      fontPath: Fonts.quicksandRegular(18),
      size: 18,
    );
    
    // Dashed line
    for (var x = 20; x < 364; x += 10) {
      img.drawLine(x, 285, x + 5, 285, thickness: 1);
    }
    
    // Totals
    await img.drawText(
      'Subtotal:',
      x: 220,
      y: 300,
      fontPath: Fonts.quicksandMedium(24),
      size: 24,
    );
    await img.drawText(
      '\$14.00',
      x: 310,
      y: 300,
      fontPath: Fonts.quicksandMedium(24),
      size: 24,
    );
    
    await img.drawText(
      'Tax:',
      x: 260,
      y: 330,
      fontPath: Fonts.quicksandRegular(18),
      size: 18,
    );
    await img.drawText(
      '\$1.26',
      x: 320,
      y: 330,
      fontPath: Fonts.quicksandRegular(18),
      size: 18,
    );
    
    // Total with inversion for emphasis
    img.fillRect(210, 355, 160, 40, radius: 5);
    await img.drawText(
      'TOTAL: \$15.26',
      x: 220,
      y: 365,
      fontPath: Fonts.quicksandBold(24),
      size: 24,
      color: 255, // White text on black background
    );
    
    // Decorative circle elements
    img.fillCircle(30, 420, 15);
    img.fillCircle(354, 420, 15);
    
    // Thank you message
    await img.drawText(
      'Thank You!',
      x: 130,
      y: 440,
      fontPath: Fonts.quicksandBold(32),
      size: 32,
    );
    
    await img.drawText(
      'Please come again',
      x: 110,
      y: 480,
      fontPath: Fonts.quicksandRegular(18),
      size: 18,
    );
    
    // Decorative rounded rectangle border
    img.drawRect(10, 10, 364, 580, radius: 10, thickness: 3);
    
    print('✓ Created complete receipt demo with fonts and graphics (384x600)');
    await printRasterImage(img, '10.0.0.166');
  } catch (e) {
    print('⚠️  Error creating receipt: $e');
    print('   (Font loading may need adjustment for your environment)');
  }
}

/// Helper function to print a raster image
Future<void> printRasterImage(RasterImageBuilder img, String printerIp) async {
  final printer = PrinterInfo(ipAddress: printerIp);
  final connection = PrinterConnection(printer);
  
  try {
    await connection.connect();
    print('Connected to printer at $printerIp');
    
    // Initialize
    await connection.sendCommand(TextCommands.initialize());
    
    // Print the image
    await connection.sendCommand(img.build());
    
    // Feed and cut
    await connection.sendCommand(TextCommands.feedAndCut(feedLines: 3));
    
    print('✓ Image printed successfully');
  } catch (e) {
    print('❌ Failed to print: $e');
  } finally {
    await connection.disconnect();
  }
}

/// Print all demos to a printer
Future<void> printAllDemos(String printerIp) async {
  print('\n=== Printing All Demos ===');
  
  final printer = PrinterInfo(ipAddress: printerIp);
  final connection = PrinterConnection(printer);
  
  try {
    await connection.connect();
    print('Connected to printer');
    
    final sequence = CommandSequence();
    sequence.add(TextCommands.initialize());
    
    // Demo 1: Rounded shapes
    final demo1 = RasterImageBuilder(384, 200);
    demo1.fillRect(20, 30, 100, 60, radius: 10);
    demo1.drawRect(140, 30, 100, 60, thickness: 2, topLeft: 20, bottomRight: 20);
    demo1.fillRect(260, 30, 100, 60, topLeft: 0, topRight: 15, bottomLeft: 15, bottomRight: 0);
    sequence.add(demo1.build());
    sequence.add(TextCommands.lineFeed(2));
    
    // Demo 2: Circles
    final demo2 = RasterImageBuilder(384, 150);
    for (var i = 0; i < 2; i++) {
      for (var j = 0; j < 4; j++) {
        final cx = 50 + j * 90;
        final cy = 40 + i * 70;
        if ((i + j) % 2 == 0) {
          demo2.fillCircle(cx, cy, 25);
        } else {
          demo2.drawCircle(cx, cy, 25);
        }
      }
    }
    sequence.add(demo2.build());
    sequence.add(TextCommands.lineFeed(2));
    
    // Demo 3: Lines and patterns
    final demo3 = RasterImageBuilder(384, 100);
    for (var i = 0; i < 5; i++) {
      demo3.drawLine(0, i * 20, 383, i * 20 + 10, thickness: 2);
    }
    sequence.add(demo3.build());
    sequence.add(TextCommands.feedAndCut(feedLines: 3));
    
    await connection.sendCommandSequence(sequence);
    print('✓ All demos printed');
    
  } catch (e) {
    print('❌ Print failed: $e');
  } finally {
    await connection.disconnect();
  }
}
