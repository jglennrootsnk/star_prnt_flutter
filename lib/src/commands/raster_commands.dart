import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import '../models/print_command.dart';

/// Commands for printing raster graphics using StarPRNT protocol
class RasterCommands {
  static const int _ESC = 0x1B;
  static const int _GS = 0x1D;

  /// Print raster graphics data (ESC GS S m xL xH yL yH n [d1...dk])
  ///
  /// [imageData] - Raw bitmap data where 1 = print, 0 = no print
  /// [width] - Width of the image in pixels
  /// [height] - Height of the image in pixels
  /// [mode] - Print mode (typically 1 for single color)
  static PrintCommand printRasterGraphics({
    required Uint8List imageData,
    required int width,
    required int height,
    int mode = 1,
  }) {
    // Calculate bytes per line (rounded up)
    final bytesPerLine = (width + 7) ~/ 8;
    
    // Verify data length
    final expectedLength = bytesPerLine * height;
    if (imageData.length != expectedLength) {
      throw ArgumentError(
        'Image data length mismatch. Expected $expectedLength, got ${imageData.length}',
      );
    }

    // Build command: ESC GS S m xL xH yL yH n [data]
    final xL = bytesPerLine & 0xFF;
    final xH = (bytesPerLine >> 8) & 0xFF;
    final yL = height & 0xFF;
    final yH = (height >> 8) & 0xFF;

    final command = <int>[
      _ESC, _GS, 0x53, // ESC GS S
      mode, // m - number of transfer blocks
      xL, xH, // width in bytes
      yL, yH, // height in dots
      0x30, // n - tone (0x30 = 2 tones)
      ...imageData, // image data
    ];

    return RawBytesCommand(Uint8List.fromList(command));
  }

  /// Print compressed raster graphics (ESC GS X m xL xH yL yH p1 p2 p3 p4 n [d1...dk])
  ///
  /// This is more efficient for images with repeated patterns
  /// Note: Compression implementation can be added for optimization
  static PrintCommand printCompressedRaster({
    required Uint8List imageData,
    required int width,
    required int height,
    int mode = 1,
  }) {
    // For now, use uncompressed version
    // TODO: Implement RLE or other compression
    return printRasterGraphics(
      imageData: imageData,
      width: width,
      height: height,
      mode: mode,
    );
  }

  /// Convert a bitmap to raster format
  ///
  /// [pixels] - 2D array where true = print (black), false = no print (white)
  /// Returns the raster data ready for printing
  static Uint8List bitmapToRaster(List<List<bool>> pixels) {
    if (pixels.isEmpty || pixels[0].isEmpty) {
      throw ArgumentError('Bitmap cannot be empty');
    }

    final height = pixels.length;
    final width = pixels[0].length;
    final bytesPerLine = (width + 7) ~/ 8;
    
    final rasterData = Uint8List(bytesPerLine * height);
    var offset = 0;

    for (var y = 0; y < height; y++) {
      if (pixels[y].length != width) {
        throw ArgumentError('All rows must have the same width');
      }

      for (var x = 0; x < bytesPerLine; x++) {
        var byte = 0;
        for (var bit = 0; bit < 8; bit++) {
          final pixelX = x * 8 + bit;
          if (pixelX < width && pixels[y][pixelX]) {
            byte |= (0x80 >> bit); // Set bit from MSB
          }
        }
        rasterData[offset++] = byte;
      }
    }

    return rasterData;
  }

  /// Convert grayscale image data to monochrome bitmap
  ///
  /// [imageData] - Grayscale pixel data (0-255)
  /// [width] - Image width
  /// [height] - Image height
  /// [threshold] - Threshold value (0-255), pixels below this become black
  static List<List<bool>> grayscaleToBitmap({
    required Uint8List imageData,
    required int width,
    required int height,
    int threshold = 128,
  }) {
    if (imageData.length != width * height) {
      throw ArgumentError('Image data length must equal width * height');
    }

    final bitmap = List.generate(
      height,
      (y) => List.generate(
        width,
        (x) {
          final pixel = imageData[y * width + x];
          return pixel < threshold; // true = black, false = white
        },
      ),
    );

    return bitmap;
  }

  /// Apply Floyd-Steinberg dithering to grayscale image
  ///
  /// This produces better quality for printing photos or gradients
  static List<List<bool>> ditherImage({
    required Uint8List imageData,
    required int width,
    required int height,
  }) {
    // Create a copy of the image data as floats for error diffusion
    final pixels = List.generate(
      height,
      (y) => List.generate(
        width,
        (x) => imageData[y * width + x].toDouble(),
      ),
    );

    final bitmap = List.generate(
      height,
      (y) => List.generate(width, (x) => false),
    );

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final oldPixel = pixels[y][x];
        final newPixel = oldPixel < 128 ? 0.0 : 255.0;
        bitmap[y][x] = newPixel == 0.0;
        
        final error = oldPixel - newPixel;

        // Distribute error to neighboring pixels (Floyd-Steinberg)
        if (x + 1 < width) {
          pixels[y][x + 1] += error * 7 / 16;
        }
        if (y + 1 < height) {
          if (x > 0) {
            pixels[y + 1][x - 1] += error * 3 / 16;
          }
          pixels[y + 1][x] += error * 5 / 16;
          if (x + 1 < width) {
            pixels[y + 1][x + 1] += error * 1 / 16;
          }
        }
      }
    }

    return bitmap;
  }

  /// Create a simple test pattern
  static PrintCommand printTestPattern({
    int width = 384, // 48mm at 203dpi
    int height = 100,
  }) {
    final bitmap = List.generate(
      height,
      (y) => List.generate(
        width,
        (x) {
          // Create a checkerboard pattern
          return ((x ~/ 10) + (y ~/ 10)) % 2 == 0;
        },
      ),
    );

    final rasterData = bitmapToRaster(bitmap);
    return printRasterGraphics(
      imageData: rasterData,
      width: width,
      height: height,
    );
  }
}

/// Helper class for building raster images with advanced drawing capabilities
/// 
/// Uses the `image` package for rendering, supporting:
/// - TrueType fonts with rotation, size, weight, and style
/// - Geometric shapes with rounded corners
/// - Image rotation (90°, 180°, 270°)
/// - Lines, circles, and arbitrary drawing
class RasterImageBuilder {
  final int width;
  final int height;
  final int rotation; // 0, 90, 180, or 270 degrees
  late img.Image _image;
  
  // Cache for loaded fonts
  static final Map<String, img.BitmapFont> _fontCache = {};

  /// Create a new raster image builder
  /// 
  /// [width] - Width in pixels
  /// [height] - Height in pixels
  /// [rotation] - Rotation angle in degrees (0, 90, 180, or 270)
  /// [backgroundColor] - Background color (0-255, where 255 is white)
  RasterImageBuilder(
    this.width,
    this.height, {
    this.rotation = 0,
    int backgroundColor = 255,
  }) {
    if (![0, 90, 180, 270].contains(rotation)) {
      throw ArgumentError('Rotation must be 0, 90, 180, or 270 degrees');
    }
    
    // Create image with white background
    _image = img.Image(
      width: width,
      height: height,
      numChannels: 1, // Grayscale
    );
    
    // Fill with background color
    img.fill(_image, color: img.ColorRgb8(backgroundColor, backgroundColor, backgroundColor));
  }

  /// Get a copy of the current image (before rotation)
  /// This is useful for debugging or saving the image to a file
  img.Image getImage() {
    return img.Image.from(_image);
  }

  /// Set a single pixel
  /// 
  /// [x] - X coordinate
  /// [y] - Y coordinate  
  /// [value] - Pixel value (0=black, 255=white, or grayscale in between)
  void setPixel(int x, int y, {int value = 0}) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      _image.setPixel(x, y, img.ColorRgb8(value, value, value));
    }
  }

  /// Get pixel value at coordinates
  int getPixel(int x, int y) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      final pixel = _image.getPixel(x, y);
      return pixel.r.toInt();
    }
    return 255; // White for out of bounds
  }

  /// Draw a horizontal line
  void drawHorizontalLine(int y, int x1, int x2, {int thickness = 1, int color = 0}) {
    img.drawLine(
      _image,
      x1: x1,
      y1: y,
      x2: x2,
      y2: y,
      color: img.ColorRgb8(color, color, color),
      thickness: thickness,
    );
  }

  /// Draw a vertical line
  void drawVerticalLine(int x, int y1, int y2, {int thickness = 1, int color = 0}) {
    img.drawLine(
      _image,
      x1: x,
      y1: y1,
      x2: x,
      y2: y2,
      color: img.ColorRgb8(color, color, color),
      thickness: thickness,
    );
  }

  /// Draw a line between two points
  /// 
  /// [x1], [y1] - Start coordinates
  /// [x2], [y2] - End coordinates
  /// [thickness] - Line thickness in pixels
  /// [color] - Line color (0=black, 255=white)
  void drawLine(int x1, int y1, int x2, int y2, {int thickness = 1, int color = 0}) {
    img.drawLine(
      _image,
      x1: x1,
      y1: y1,
      x2: x2,
      y2: y2,
      color: img.ColorRgb8(color, color, color),
      thickness: thickness,
    );
  }

  /// Draw a rectangle outline
  /// 
  /// [x], [y] - Top-left corner
  /// [w], [h] - Width and height
  /// [thickness] - Line thickness
  /// [color] - Line color (0=black, 255=white)
  /// [radius] - Uniform corner radius for all corners
  /// [topLeft], [topRight], [bottomLeft], [bottomRight] - Individual corner radii (override radius)
  void drawRect(
    int x,
    int y,
    int w,
    int h, {
    int thickness = 1,
    int color = 0,
    int? radius,
    int? topLeft,
    int? topRight,
    int? bottomLeft,
    int? bottomRight,
  }) {
    // Determine corner radii
    final tl = topLeft ?? radius ?? 0;
    final tr = topRight ?? radius ?? 0;
    final bl = bottomLeft ?? radius ?? 0;
    final br = bottomRight ?? radius ?? 0;

    final imgColor = img.ColorRgb8(color, color, color);

    // Check if all corners have the same radius
    if (tl == tr && tr == bl && bl == br) {
      // Use built-in drawRect with radius parameter (supports uniform corners)
      img.drawRect(
        _image,
        x1: x,
        y1: y,
        x2: x + w - 1,
        y2: y + h - 1,
        color: imgColor,
        radius: tl,
        thickness: thickness,
      );
    } else {
      // Different corner radii - must draw manually
      _drawRoundedRectOutline(x, y, w, h, tl, tr, bl, br, color, thickness);
    }
  }

  /// Draw a filled rectangle
  /// 
  /// [x], [y] - Top-left corner
  /// [w], [h] - Width and height
  /// [color] - Fill color (0=black, 255=white)
  /// [radius] - Uniform corner radius for all corners
  /// [topLeft], [topRight], [bottomLeft], [bottomRight] - Individual corner radii (override radius)
  void fillRect(
    int x,
    int y,
    int w,
    int h, {
    int color = 0,
    int? radius,
    int? topLeft,
    int? topRight,
    int? bottomLeft,
    int? bottomRight,
  }) {
    // Determine corner radii
    final tl = topLeft ?? radius ?? 0;
    final tr = topRight ?? radius ?? 0;
    final bl = bottomLeft ?? radius ?? 0;
    final br = bottomRight ?? radius ?? 0;

    final imgColor = img.ColorRgb8(color, color, color);

    // Check if all corners have the same radius
    if (tl == tr && tr == bl && bl == br) {
      // Use built-in fillRect with radius parameter (supports uniform corners)
      img.fillRect(
        _image,
        x1: x,
        y1: y,
        x2: x + w - 1,
        y2: y + h - 1,
        color: imgColor,
        radius: tl,
      );
    } else {
      // Different corner radii - must draw manually
      _drawRoundedRectFilled(x, y, w, h, tl, tr, bl, br, color);
    }
  }

  /// Helper to draw rounded rectangle outline with different corner radii
  void _drawRoundedRectOutline(
    int x, int y, int w, int h,
    int tl, int tr, int bl, int br,
    int color, int thickness,
  ) {
    final imgColor = img.ColorRgb8(color, color, color);
    
    // Draw straight edges between corners
    // Top edge
    if (tl > 0 || tr > 0) {
      img.drawLine(_image,
        x1: x + tl, y1: y,
        x2: x + w - tr - 1, y2: y,
        color: imgColor, thickness: thickness,
      );
    } else {
      img.drawLine(_image,
        x1: x, y1: y,
        x2: x + w - 1, y2: y,
        color: imgColor, thickness: thickness,
      );
    }
    
    // Bottom edge
    if (bl > 0 || br > 0) {
      img.drawLine(_image,
        x1: x + bl, y1: y + h - 1,
        x2: x + w - br - 1, y2: y + h - 1,
        color: imgColor, thickness: thickness,
      );
    } else {
      img.drawLine(_image,
        x1: x, y1: y + h - 1,
        x2: x + w - 1, y2: y + h - 1,
        color: imgColor, thickness: thickness,
      );
    }
    
    // Left edge
    if (tl > 0 || bl > 0) {
      img.drawLine(_image,
        x1: x, y1: y + tl,
        x2: x, y2: y + h - bl - 1,
        color: imgColor, thickness: thickness,
      );
    } else {
      img.drawLine(_image,
        x1: x, y1: y,
        x2: x, y2: y + h - 1,
        color: imgColor, thickness: thickness,
      );
    }
    
    // Right edge
    if (tr > 0 || br > 0) {
      img.drawLine(_image,
        x1: x + w - 1, y1: y + tr,
        x2: x + w - 1, y2: y + h - br - 1,
        color: imgColor, thickness: thickness,
      );
    } else {
      img.drawLine(_image,
        x1: x + w - 1, y1: y,
        x2: x + w - 1, y2: y + h - 1,
        color: imgColor, thickness: thickness,
      );
    }
    
    // Draw corner arcs using the image package's built-in circle drawing
    if (tl > 0) {
      _drawCornerArc(_image, x + tl, y + tl, tl, 180, 270, imgColor, thickness);
    }
    if (tr > 0) {
      _drawCornerArc(_image, x + w - tr - 1, y + tr, tr, 270, 360, imgColor, thickness);
    }
    if (bl > 0) {
      _drawCornerArc(_image, x + bl, y + h - bl - 1, bl, 90, 180, imgColor, thickness);
    }
    if (br > 0) {
      _drawCornerArc(_image, x + w - br - 1, y + h - br - 1, br, 0, 90, imgColor, thickness);
    }
  }

  /// Helper to draw filled rounded rectangle with different corner radii
  void _drawRoundedRectFilled(
    int x, int y, int w, int h,
    int tl, int tr, int bl, int br,
    int color,
  ) {
    final imgColor = img.ColorRgb8(color, color, color);
    
    // Fill the main rectangular areas
    // Center rectangle (full height, accounting for left/right corners)
    final leftInset = tl > bl ? tl : bl;
    final rightInset = tr > br ? tr : br;
    img.fillRect(_image,
      x1: x + leftInset,
      y1: y,
      x2: x + w - rightInset - 1,
      y2: y + h - 1,
      color: imgColor,
    );
    
    // Top-left corner area
    if (tl > 0) {
      img.fillRect(_image,
        x1: x,
        y1: y + tl,
        x2: x + tl - 1,
        y2: y + h - (bl > tl ? bl : tl) - 1,
        color: imgColor,
      );
    }
    
    // Top-right corner area
    if (tr > 0) {
      img.fillRect(_image,
        x1: x + w - tr,
        y1: y + tr,
        x2: x + w - 1,
        y2: y + h - (br > tr ? br : tr) - 1,
        color: imgColor,
      );
    }
    
    // Fill corner circles
    if (tl > 0) {
      img.fillCircle(_image, x: x + tl, y: y + tl, radius: tl, color: imgColor);
    }
    if (tr > 0) {
      img.fillCircle(_image, x: x + w - tr - 1, y: y + tr, radius: tr, color: imgColor);
    }
    if (bl > 0) {
      img.fillCircle(_image, x: x + bl, y: y + h - bl - 1, radius: bl, color: imgColor);
    }
    if (br > 0) {
      img.fillCircle(_image, x: x + w - br - 1, y: y + h - br - 1, radius: br, color: imgColor);
    }
  }

  /// Draw a corner arc (quarter circle)
  void _drawCornerArc(
    img.Image image,
    int cx, int cy, int radius,
    int startAngle, int endAngle,
    img.Color color, int thickness,
  ) {
    // Draw multiple circles with decreasing radii for thickness
    for (var t = 0; t < thickness; t++) {
      final r = radius - (thickness ~/ 2) + t;
      if (r <= 0) continue;
      
      // Calculate points along the arc
      final steps = ((endAngle - startAngle).abs() * 2).toInt(); // More steps for smoother arc
      for (var i = 0; i <= steps; i++) {
        final angle = (startAngle + (endAngle - startAngle) * i / steps) * pi / 180;
        final x = (cx + r * cos(angle)).round();
        final y = (cy + r * sin(angle)).round();
        
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          image.setPixel(x, y, color);
        }
      }
    }
  }

  /// Draw a circle outline
  /// 
  /// [cx], [cy] - Center coordinates
  /// [radius] - Circle radius
  /// [thickness] - Line thickness
  /// [color] - Line color (0=black, 255=white)
  void drawCircle(int cx, int cy, int radius, {int thickness = 1, int color = 0}) {
    final imgColor = img.ColorRgb8(color, color, color);
    
    if (thickness == 1) {
      // Use built-in function for single pixel thickness
      img.drawCircle(
        _image,
        x: cx,
        y: cy,
        radius: radius,
        color: imgColor,
      );
    } else {
      // Draw multiple circles for thickness
      for (var t = 0; t < thickness; t++) {
        final r = radius - (thickness ~/ 2) + t;
        if (r > 0) {
          img.drawCircle(
            _image,
            x: cx,
            y: cy,
            radius: r,
            color: imgColor,
          );
        }
      }
    }
  }

  /// Draw a filled circle
  /// 
  /// [cx], [cy] - Center coordinates
  /// [radius] - Circle radius
  /// [color] - Fill color (0=black, 255=white)
  void fillCircle(int cx, int cy, int radius, {int color = 0}) {
    img.fillCircle(
      _image,
      x: cx,
      y: cy,
      radius: radius,
      color: img.ColorRgb8(color, color, color),
    );
  }

  /// Draw text using a TrueType font
  /// 
  /// [text] - The text to draw
  /// [x], [y] - Position (baseline left for 0° rotation)
  /// [fontPath] - Path to TTF/OTF font file
  /// [size] - Font size in points
  /// [color] - Text color (0=black, 255=white)
  /// [rotation] - Text rotation in degrees (any angle supported)
  /// [bold] - Apply bold effect (renders twice with offset)
  /// [italic] - Apply italic effect (shear transformation)
  /// [underline] - Draw underline
  /// [underlineThickness] - Underline thickness in pixels
  Future<void> drawText(
    String text, {
    required int x,
    required int y,
    required String fontPath,
    double size = 12,
    int color = 0,
    double rotation = 0,
    bool bold = false,
    bool italic = false,
    bool underline = false,
    int underlineThickness = 1,
  }) async {
    // Load or get cached font
    final font = await _loadTrueTypeFont(fontPath, size);
    // Create temporary image for text - just large enough to hold the text
      final textWidth = _measureText(text, font);
      final textHeight = size.ceil();
      final tempImg = img.Image(
        width: (textWidth + 4).ceil(),  // Small margin to prevent clipping
        height: (textHeight + 4).ceil(),
        numChannels: 1,
      );
    //
    img.drawString(
      _image,
      text,
      font: font,
      x: x,
      y: y,
      color: img.ColorRgb8(color, color, color),
    );
    if (underline) {
        drawLine(x, y + 2, x + textWidth, y + 2, 
          thickness: underlineThickness, color: color);
      }
      // Rotate if needed
      // img.Image rotatedImg = tempImg;
      // if (rotation != 0) {
      //   rotatedImg = img.copyRotate(tempImg, angle: rotation);
      // }
      
      // Composite onto main image, compensating for the 2px margin
      // img.compositeImage(_image, rotatedImg, dstX: x - 2, dstY: y - 2);
    }
  

  /// Load a bitmap font file
  /// 
  /// Supports:
  /// - .zip files containing bitmap fonts (from BMFont, AngelCode, etc.)
  /// - Built-in fonts from the image package
  /// 
  /// For bitmap fonts:
  /// - Create separate font files for each size you need (12pt, 16pt, 24pt, etc.)
  /// - Don't scale bitmap fonts - use the exact size for best quality
  /// - Fonts are automatically cached for performance
  Future<img.BitmapFont> _loadBitmapFont(String fontPath, double size) async {
    final cacheKey = '$fontPath:$size';
    
    if (_fontCache.containsKey(cacheKey)) {
      return _fontCache[cacheKey]!;
    }
    
    // Load the font file
    final fontFile = File(fontPath);
    if (!await fontFile.exists()) {
      throw Exception('Font file not found: $fontPath');
    }
    
    final fontBytes = await fontFile.readAsBytes();
    
    // Load bitmap font from zip file
    // The image package supports bitmap fonts in zip format
    try {
      final font = img.BitmapFont.fromZip(fontBytes);
      _fontCache[cacheKey] = font;
      return font;
    } catch (e) {
      throw Exception('Failed to load bitmap font from $fontPath: $e');
    }
  }

  /// Load a font (attempts to find the best matching size)
  Future<img.BitmapFont> _loadTrueTypeFont(String fontPath, double size) async {
    // For bitmap fonts, try to load the exact size or closest match
    return await _loadBitmapFont(fontPath, size);
  }

  /// Measure text width accurately using font metrics
  int _measureText(String text, img.BitmapFont font) {
    var width = 0.0;
    for (var i = 0; i < text.length; i++) {
      final char = text.codeUnitAt(i);
      final glyph = font.characters[char];
      if (glyph != null) {
        // Use the character width from the bitmap font
        width += glyph.width.toDouble();
      } else {
        // Fallback width for missing characters
        width += 8.0;
      }
    }
    return width.round();
  }

  /// Composite another image onto this one
  /// 
  /// [sourceImage] - The image to composite
  /// [x], [y] - Position to place the image
  /// [blend] - Blending mode
  void drawImage(RasterImageBuilder sourceImage, int x, int y) {
    img.compositeImage(_image, sourceImage._image, dstX: x, dstY: y);
  }

  /// Invert colors in a rectangular region
  /// 
  /// [x], [y] - Top-left corner
  /// [w], [h] - Width and height (null = entire image)
  void invert({int? x, int? y, int? w, int? h}) {
    final x1 = x ?? 0;
    final y1 = y ?? 0;
    final x2 = x1 + (w ?? width);
    final y2 = y1 + (h ?? height);
    
    for (var py = y1; py < y2 && py < height; py++) {
      for (var px = x1; px < x2 && px < width; px++) {
        final pixel = _image.getPixel(px, py);
        final inverted = 255 - pixel.r.toInt();
        _image.setPixel(px, py, img.ColorRgb8(inverted, inverted, inverted));
      }
    }
  }

  /// Clear the image to a specific color
  /// 
  /// [color] - Color to fill (0=black, 255=white)
  void clear({int color = 255}) {
    img.fill(_image, color: img.ColorRgb8(color, color, color));
  }

  /// Apply rotation to the final image
  void _applyRotation() {
    if (rotation == 90) {
      _image = img.copyRotate(_image, angle: 90);
    } else if (rotation == 180) {
      _image = img.copyRotate(_image, angle: 180);
    } else if (rotation == 270) {
      _image = img.copyRotate(_image, angle: 270);
    }
  }

  /// Build the raster command
  /// 
  /// [threshold] - Grayscale threshold for black/white conversion (0-255)
  ///               Values below threshold become black, above become white
  ///               Default is 128 (50% gray)
  PrintCommand build({int threshold = 128}) {
    // Apply rotation if specified
    _applyRotation();
    
    // Convert to monochrome bitmap with custom threshold
    final bitmap = _imageToBitmap(_image, threshold: threshold);
    final rasterData = RasterCommands.bitmapToRaster(bitmap);
    
    return RasterCommands.printRasterGraphics(
      imageData: rasterData,
      width: _image.width,
      height: _image.height,
    );
  }

  /// Convert image to boolean bitmap
  /// 
  /// [image] - Source grayscale image
  /// [threshold] - Threshold value (0-255), pixels below this become black
  List<List<bool>> _imageToBitmap(img.Image image, {int threshold = 128}) {
    return List.generate(
      image.height,
      (y) => List.generate(
        image.width,
        (x) {
          final pixel = image.getPixel(x, y);
          final gray = pixel.r.toInt();
          return gray < threshold; // true = black, false = white
        },
      ),
    );
  }

  /// Get the underlying image for advanced manipulation
  img.Image get image => _image;

  /// Get the bitmap data with custom threshold
  /// 
  /// [threshold] - Threshold for black/white conversion (default: 128)
  List<List<bool>> getBitmap({int threshold = 128}) => _imageToBitmap(_image, threshold: threshold);
}

/// Simple math helpers
double cos(double radians) {
  // Simple cosine approximation
  final x = radians % (2 * 3.14159);
  return 1 - (x * x) / 2 + (x * x * x * x) / 24;
}

double sin(double radians) {
  return cos(radians - 3.14159 / 2);
}
