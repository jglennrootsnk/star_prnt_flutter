import 'dart:io';
import 'package:star_prnt_flutter/star_prnt_flutter.dart';
import 'package:image/image.dart' as img;

/// Generates a food order label matching the provided design
/// 
/// Label dimensions: 3" wide × 2" tall at 300 DPI = 900×600 pixels
/// Built in landscape orientation then rotated 90° counter-clockwise for printing
/// 
/// Label layout:
/// - Top row: Logo (left), Customer name (center), Platform icon (right)
/// - Horizontal line separator
/// - Second row: Item index + name (center, large bold)
/// - Middle: Ingredients text (wrapped, left-aligned)
/// - Bottom row in rounded boxes: Order#, Eat before date, Order type
class BowlLabelGenerator {
  /// Generate a food order label
  /// 
  /// Parameters:
  /// - [font18Path] - Path to 18px bitmap font .zip file
  /// - [font24Path] - Path to 24px bitmap font .zip file
  /// - [font32Path] - Path to 32px bitmap font .zip file
  /// - [font48Path] - Path to 48px bitmap font .zip file
  /// - [customerName] - Customer name for top center (e.g., "Colin G")
  /// - [platformIconPath] - Path to platform icon PNG (e.g., './icons/doordash.png')
  /// - [itemIndex] - Item number in format "(X of Y)" (e.g., "(2 of 4)")
  /// - [itemName] - Name of the item (e.g., "El Jefe")
  /// - [itemIngredients] - Ingredient list with modifiers (e.g., "Brown Rice (P), Kale (S), ...")
  /// - [orderNumber] - Order number (e.g., "9678039")
  /// - [eatByDate] - Eat before date (e.g., "10/11/2025")
  /// - [orderType] - Type of order (e.g., "Delivery")
  /// - [logoPath] - Optional path to top-left logo PNG
  /// 
  /// Returns a PrintCommand ready to send to the printer
  static Future<PrintCommand> generateLabel({
    required String font18Path,
    required String font24Path,
    required String font32Path,
    required String font48Path,
    required String font72Path,
    required String customerName,
    required String platformIconPath,
    required String itemIndex,
    required String itemName,
    required String itemIngredients,
    required String orderNumber,
    required String eatByDate,
    required String orderType,
    String? logoPath,
    bool mock = false,
  }) async {
    // Label dimensions: 3" wide × 2" tall at 300 DPI
    // Build in landscape (900w × 600h), will rotate 90° CCW for printing
    const labelWidth = 900;  // 3 inches × 300 DPI
    const labelHeight = 600; // 2 inches × 300 DPI
    
    // Note: Will be rotated 90° CCW after building, so "width" becomes height when printed
    final builder = RasterImageBuilder(
      labelWidth, 
      labelHeight,
      rotation: 270, // 90° counter-clockwise = 270° clockwise
    );
    
    // Layout constants (in pixels at 300 DPI)
    const topMargin = 20;
    const sideMargin = 30;
    const lineHeight = 25;
    const logoSize = 120;
    const iconSize = 72; // Match top text height
    
    var currentY = topMargin;
    
    // === TOP ROW: Logo (left), Customer Name (center), Platform Icon (right) ===
    
    // Draw logo if provided (top-left)
    if (logoPath != null) {
      try {
        await _drawImageFromFile(
          builder,
          logoPath,
          x: sideMargin,
          y: currentY,
          maxWidth: logoSize,
          maxHeight: logoSize,
        );
      } catch (e) {
        print('Warning: Could not load logo: $e');
      }
    }
    
    // Draw customer name (top-center) - 72px bold
    // Approximate text width: 72px font ≈ 36px per char average
    // limit customername to 18 chars to avoid overflow
    if (customerName.length > 19) {
      customerName = customerName.substring(0, 18);
    }
    final customerNameWidth = customerName.length * 36;
    await builder.drawText(
      customerName,
      x: (labelWidth - customerNameWidth) ~/ 2,
      y: currentY + 10,
      fontPath: font72Path,
      size: 72.0,
      bold: true,
    );
    
    // Draw platform icon (top-right) - proportional to text height
    try {
      await _drawImageFromFile(
        builder,
        platformIconPath,
        x: labelWidth - sideMargin - iconSize,
        y: currentY,
        maxWidth: iconSize,
        maxHeight: 100,
      );
    } catch (e) {
      print('Warning: Could not load platform icon: $e');
    }
    
    currentY += logoSize; // Space after top row
    
    // === HORIZONTAL LINE ===
    builder.drawLine(
      sideMargin,
      currentY,
      labelWidth - sideMargin,
      currentY,
      thickness: 8,
      color: 0,
    );
    currentY += 15;
    
    // === SECOND ROW: Item Index + Name (center, large bold) ===
    // Use 48px bold for item title
    final itemTitle = '$itemIndex $itemName';
    final itemTitleWidth = itemTitle.length * 24; // 48px font ≈ 24px per char
    await builder.drawText(
      itemTitle,
      x: (labelWidth - itemTitleWidth) ~/ 2,
      y: currentY,
      fontPath: font48Path,
      size: 48.0,
      bold: true,
    );
    
    currentY += 60; // Space after title
    
    // === INGREDIENTS SECTION (wrapped text, left-aligned) ===
    // Use 32px font for ingredients
    final ingredientLines = _wrapText(
      itemIngredients,
      maxWidth: labelWidth - (sideMargin * 2),
      charWidth: 16, // 32px font ≈ 16px per char
    );
    
    for (final line in ingredientLines) {
      await builder.drawText(
        line,
        x: sideMargin,
        y: currentY,
        fontPath: font32Path,
        size: 32.0,
      );
      currentY += lineHeight;
    }
    
    currentY += 20; // Space before bottom section
    
    // === BOTTOM SECTION: Three boxes with rounded corners (radius 15) ===
    final boxY = 480;
    final boxHeight = 100;
    final gapBetweenBoxes = 15;
    final boxWidth = (labelWidth - (sideMargin * 2) - (gapBetweenBoxes * 2)) ~/ 3;
    final boxThickness = 10;
    // Box 1: Order Number
    _drawBox(
      builder,
      x: sideMargin,
      y: boxY,
      width: boxWidth,
      height: boxHeight,
      thickness: boxThickness,
      cornerRadius: 25,
    );
    await builder.drawText(
      'Order#',
      x: sideMargin + 15,
      y: boxY + 15,
      fontPath: font24Path,
      size: 24.0,
    );
    await builder.drawText(
      orderNumber,
      x: sideMargin + 15,
      y: boxY + 40,
      fontPath: font48Path,
      size: 48.0,
      bold: true,
    );
    
    // Box 2: Eat Before Date
    final box2X = sideMargin + boxWidth + gapBetweenBoxes;
    _drawBox(
      builder,
      x: box2X,
      y: boxY,
      width: boxWidth,
      height: boxHeight,
      thickness: boxThickness,
      cornerRadius: 15,
    );
    await builder.drawText(
      'Eat before:',
      x: box2X + 15,
      y: boxY + 15,
      fontPath: font24Path,
      size: 24.0,
    );
    await builder.drawText(
      eatByDate,
      x: box2X + 5,
      y: boxY + 40,
      fontPath: font48Path,
      size: 48.0,
      bold: true,
    );
    
    // Box 3: Order Type
    final box3X = box2X + boxWidth + gapBetweenBoxes;
    _drawBox(
      builder,
      x: box3X,
      y: boxY,
      width: boxWidth,
      height: boxHeight,
      thickness: boxThickness,
      cornerRadius: 15,
    );
    await builder.drawText(
      'Type:',
      x: box3X + 15,
      y: boxY + 15,
      fontPath: font24Path,
      size: 24.0,
    );
    await builder.drawText(
      orderType,
      x: box3X + 15,
      y: boxY + 40,
      fontPath: font48Path,
      size: 48.0,
      bold: true,
    );
    
    // Build and return the print command
    // Threshold: lower = more black, higher = more white
    
    // If mock mode, save the image to a file
    if (mock) {
      await _saveImageToFile(builder);
    }
    
    return builder.build(threshold: 128);
  }
  
  /// Helper: Save the builder's image to a PNG file
  static Future<void> _saveImageToFile(RasterImageBuilder builder) async {
    try {
      // Create output directory if it doesn't exist
      final outputDir = Directory('./label-output');
      if (!await outputDir.exists()) {
        await outputDir.create(recursive: true);
      }
      
      // Generate timestamp for filename
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
      final outputPath = './label-output/label-$timestamp.png';
      
      // Get the current image from the builder (before rotation and thresholding)
      final image = builder.getImage();
      
      print('Saving mock label to: $outputPath');
      
      // Encode and save
      final pngBytes = img.encodePng(image);
      final file = File(outputPath);
      await file.writeAsBytes(pngBytes);
      
      print('✓ Mock label saved to: $outputPath');
    } catch (e) {
      print('Warning: Could not save mock image: $e');
    }
  }
  
  /// Helper: Draw a rounded rectangle box
  static void _drawBox(
    RasterImageBuilder builder, {
    required int x,
    required int y,
    required int width,
    required int height,
    int thickness = 3,
    int cornerRadius = 15,
  }) {
    builder.drawRect(
      x,
      y,
      width,
      height,
      color: 0,
      thickness: thickness,
      radius: cornerRadius,
    );
  }
  
  /// Helper: Wrap text to fit within a maximum width
  static List<String> _wrapText(String text, {required int maxWidth, required int charWidth}) {
    final words = text.split(' ');
    final lines = <String>[];
    var currentLine = '';
    
    for (final word in words) {
      final testLine = currentLine.isEmpty ? word : '$currentLine $word';
      final testWidth = testLine.length * charWidth;
      
      if (testWidth <= maxWidth) {
        currentLine = testLine;
      } else {
        if (currentLine.isNotEmpty) {
          lines.add(currentLine);
        }
        currentLine = word;
      }
    }
    
    if (currentLine.isNotEmpty) {
      lines.add(currentLine);
    }
    
    return lines;
  }
  
  /// Helper: Load and draw an image from file
  static Future<void> _drawImageFromFile(
    RasterImageBuilder builder,
    String imagePath, {
    required int x,
    required int y,
    int? maxWidth,
    int? maxHeight,
  }) async {
    // Load the image
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Image file not found: $imagePath');
    }
    
    final imageBytes = await file.readAsBytes();
    var image = img.decodeImage(imageBytes);
    
    if (image == null) {
      throw Exception('Failed to decode image: $imagePath');
    }
    
    // Resize if needed
    if (maxWidth != null && image.width > maxWidth) {
      image = img.copyResize(image, width: maxWidth);
    }
    if (maxHeight != null && image.height > maxHeight) {
      image = img.copyResize(image, height: maxHeight);
    }
    
    // Convert to grayscale
    final grayImage = img.grayscale(image);
    
    // Draw pixel by pixel
    for (var py = 0; py < grayImage.height; py++) {
      for (var px = 0; px < grayImage.width; px++) {
        final pixel = grayImage.getPixel(px, py);
        final gray = pixel.r.toInt();
        builder.setPixel(x + px, y + py, value: gray);
      }
    }
  }
}

/// Example usage
Future<void> printExampleBowlLabel(String printerIp) async {
  // Generate the label
  final labelCommand = await BowlLabelGenerator.generateLabel(
    font18Path: './fonts/arial_18.zip',  // 18px font for ingredients & labels
    font24Path: './fonts/arial_24.zip',  // 24px font for dates
    font32Path: './fonts/arial_32.zip',  // 32px font for large numbers
    font48Path: './fonts/arial_48.zip',  // 48px font for titles
    font72Path: './fonts/arial_72.zip',  // 72px font if order title
    customerName: 'Colin G',
    platformIconPath: './icons/doordash.png',
    itemIndex: '(2 of 4)',
    itemName: 'El Jefe',
    itemIngredients: 'Brown Rice (P), Kale (S), Avocado, -Blk Beans, +Broccoli, '
        'Corn, +Cheddar, -Tabasco, -Feta, -Lime, -Pita, -Onions, '
        '+Sweets, -Tabasco, -Lime, Chicken, -Cil Lime, +Pesto',
    orderNumber: '9678039',
    eatByDate: '10/11/2025',
    orderType: 'Delivery',
    logoPath: './icons/logo.png', // Optional
  );
  
  // Print the label
  final printer = PrinterInfo(ipAddress: printerIp);
  final connection = PrinterConnection(printer);
  
  try {
    await connection.connect();
    await connection.sendCommand(labelCommand);
    await connection.sendCommand(TextCommands.lineFeed(3));
    await connection.disconnect();
    print('✓ Label printed successfully');
  } catch (e) {
    print('❌ Error printing label: $e');
  }
}
