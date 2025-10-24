import 'dart:convert';
import 'dart:typed_data';
import '../models/print_command.dart';

/// Commands for printing graphics like barcodes and QR codes
class GraphicsCommands {
  static const int _ESC = 0x1B;
  static const int _GS = 0x1D;

  /// Print a QR code (ESC GS y S 0 n)
  ///
  /// [data] - The data to encode in the QR code
  /// [cellSize] - Size of each QR code cell (1-8, default 3)
  /// [errorCorrection] - Error correction level (0-3: L,M,Q,H)
  static PrintCommand printQRCode({
    required String data,
    int cellSize = 3,
    int errorCorrection = 1,
  }) {
    assert(cellSize >= 1 && cellSize <= 8);
    assert(errorCorrection >= 0 && errorCorrection <= 3);

    final dataBytes = utf8.encode(data);
    final dataLength = dataBytes.length;
    final nL = dataLength & 0xFF;
    final nH = (dataLength >> 8) & 0xFF;

    final commands = <int>[];

    // Set QR code model (Model 2)
    commands.addAll([_ESC, _GS, 0x79, 0x53, 0x30, 0x00]);

    // Set cell size
    commands.addAll([_ESC, _GS, 0x79, 0x53, 0x32, cellSize]);

    // Set error correction level
    commands.addAll([_ESC, _GS, 0x79, 0x53, 0x31, errorCorrection]);

    // Store data
    commands.addAll([
      _ESC, _GS, 0x79, 0x44, 0x31, 0x00,
      nL, nH, // data length
      ...dataBytes, // QR data
    ]);

    // Print QR code
    commands.addAll([_ESC, _GS, 0x79, 0x50]);

    return RawBytesCommand(Uint8List.fromList(commands));
  }

  /// Print a 1D barcode (ESC b n1 n2 n3 n4 n5 d1...dk)
  ///
  /// [data] - The barcode data
  /// [type] - Barcode type (see StarPRNT specification)
  /// [width] - Module width (2-4)
  /// [height] - Barcode height in dots (1-255)
  /// [hri] - Human Readable Interpretation position
  ///         0=none, 1=above, 2=below, 3=both
  static PrintCommand printBarcode({
  required String data,
  int type = 4, // CODE39
  int width = 2,
  int height = 60,
  int hri = 2,
}) {
  assert(width >= 2 && width <= 4);
  assert(height >= 1 && height <= 255);
  assert(hri >= 0 && hri <= 3);

  final dataBytes = ascii.encode(data);

  final commands = <int>[
    _ESC, 0x62,        // ESC b
    type,              // n1: barcode type
    hri,               // n2: HRI position
    width,             // n3: module width
    height,            // n4: height
    ...dataBytes,      // d1...dk: barcode data
    0x1E,              // RS terminator
  ];

  return RawBytesCommand(Uint8List.fromList(commands));
}

  /// Barcode types for use with printBarcode
  static const int barcodeTypeUPCE = 0;
  static const int barcodeTypeUPCA = 1;
  static const int barcodeTypeJAN8 = 2;
  static const int barcodeTypeJAN13 = 3;
  static const int barcodeTypeCODE39 = 4;
  static const int barcodeTypeITF = 5;
  static const int barcodeTypeCODE128 = 6;
  static const int barcodeTypeCODE93 = 7;
  static const int barcodeTypeNW7 = 8;

  /// Print a PDF417 2D barcode
  ///
  /// [data] - The data to encode
  /// [columnCount] - Number of columns (0=auto, 1-30)
  /// [rowCount] - Number of rows (0=auto, 3-90)
  /// [moduleWidth] - Width of each module (2-8)
  /// [moduleHeight] - Height of each module (2-8)
  /// [errorCorrection] - Error correction level (0-8)
  static PrintCommand printPDF417({
    required String data,
    int columnCount = 0,
    int rowCount = 0,
    int moduleWidth = 3,
    int moduleHeight = 3,
    int errorCorrection = 1,
  }) {
    final dataBytes = utf8.encode(data);
    final dataLength = dataBytes.length;
    final nL = dataLength & 0xFF;
    final nH = (dataLength >> 8) & 0xFF;

    final commands = <int>[];

    // Set column count
    commands.addAll([_ESC, _GS, 0x78, 0x53, 0x30, columnCount]);

    // Set row count
    commands.addAll([_ESC, _GS, 0x78, 0x53, 0x31, rowCount]);

    // Set module width
    commands.addAll([_ESC, _GS, 0x78, 0x53, 0x32, moduleWidth]);

    // Set module height
    commands.addAll([_ESC, _GS, 0x78, 0x53, 0x33, moduleHeight]);

    // Set error correction
    commands.addAll([_ESC, _GS, 0x78, 0x53, 0x34, errorCorrection]);

    // Store data
    commands.addAll([
      _ESC, _GS, 0x78, 0x44, 0x30, 0x00,
      nL, nH,
      ...dataBytes,
    ]);

    // Print PDF417
    commands.addAll([_ESC, _GS, 0x78, 0x50]);

    return RawBytesCommand(Uint8List.fromList(commands));
  }

  /// Print stored NV graphics/logo (ESC GS ( L)
  ///
  /// [keyCode] - The key code of the stored logo (1-255)
  /// [xScale] - Horizontal scale (1-255)
  /// [yScale] - Vertical scale (1-255)
  static PrintCommand printNVGraphics({
    required int keyCode,
    int xScale = 1,
    int yScale = 1,
  }) {
    assert(keyCode >= 1 && keyCode <= 255);
    assert(xScale >= 1 && xScale <= 255);
    assert(yScale >= 1 && yScale <= 255);

    final commands = <int>[
      _ESC, _GS, 0x28, 0x4C, // ESC GS ( L
      0x06, 0x00, // pL, pH (parameter length = 6)
      0x45, 0x00, // fn = 69 (print)
      keyCode, 0x00, // key code
      xScale, // x scale
      yScale, // y scale
    ];

    return RawBytesCommand(Uint8List.fromList(commands));
  }

  /// Print a horizontal rule (line)
  ///
  /// [width] - Width in characters (use 0 for full width)
  /// [char] - Character to use for the line (default: dash)
  static PrintCommand printRule({int width = 32, String char = '-'}) {
    final line = char * width;
    final bytes = ascii.encode(line + '\n');
    return RawBytesCommand(Uint8List.fromList(bytes));
  }
}

/// Builder for creating complex graphics layouts
class GraphicsBuilder {
  final List<PrintCommand> _commands = [];

  GraphicsBuilder();

  /// Add a QR code
  GraphicsBuilder qrCode(
    String data, {
    int cellSize = 3,
    int errorCorrection = 1,
  }) {
    _commands.add(GraphicsCommands.printQRCode(
      data: data,
      cellSize: cellSize,
      errorCorrection: errorCorrection,
    ));
    return this;
  }

  /// Add a barcode
  GraphicsBuilder barcode(
    String data, {
    int type = GraphicsCommands.barcodeTypeCODE39,
    int width = 2,
    int height = 60,
    int hri = 2,
  }) {
    _commands.add(GraphicsCommands.printBarcode(
      data: data,
      type: type,
      width: width,
      height: height,
      hri: hri,
    ));
    return this;
  }

  /// Add a PDF417 barcode
  GraphicsBuilder pdf417(
    String data, {
    int columnCount = 0,
    int rowCount = 0,
    int moduleWidth = 3,
    int moduleHeight = 3,
    int errorCorrection = 1,
  }) {
    _commands.add(GraphicsCommands.printPDF417(
      data: data,
      columnCount: columnCount,
      rowCount: rowCount,
      moduleWidth: moduleWidth,
      moduleHeight: moduleHeight,
      errorCorrection: errorCorrection,
    ));
    return this;
  }

  /// Add a horizontal rule
  GraphicsBuilder rule({int width = 32, String char = '-'}) {
    _commands.add(GraphicsCommands.printRule(width: width, char: char));
    return this;
  }

  /// Add a custom command
  GraphicsBuilder custom(PrintCommand command) {
    _commands.add(command);
    return this;
  }

  /// Build the command sequence
  List<PrintCommand> build() {
    return _commands;
  }

  /// Convert to bytes
  Uint8List toBytes() {
    final totalLength = _commands.fold<int>(
      0,
      (sum, cmd) => sum + cmd.toBytes().length,
    );

    final result = Uint8List(totalLength);
    var offset = 0;

    for (final command in _commands) {
      final bytes = command.toBytes();
      result.setRange(offset, offset + bytes.length, bytes);
      offset += bytes.length;
    }

    return result;
  }
}
