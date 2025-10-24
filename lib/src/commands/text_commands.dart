import 'dart:convert';
import 'dart:typed_data';
import '../models/print_command.dart';

/// Commands for printing text using StarPRNT protocol
class TextCommands {
  // ESC/POS control characters
  static const int _ESC = 0x1B;
  static const int _GS = 0x1D;
  static const int _LF = 0x0A;
  static const int _FF = 0x0C;
  static const int _HT = 0x09;

  /// Initialize printer (ESC @)
  static PrintCommand initialize() {
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x40]));
  }

  /// Print text with automatic line feed
  static PrintCommand printText(String text) {
    final bytes = latin1.encode(text);
    return RawBytesCommand(Uint8List.fromList(bytes));
  }

  /// Print text with line feed (LF)
  static PrintCommand printLine(String text) {
    final bytes = latin1.encode(text);
    return RawBytesCommand(
      Uint8List.fromList([...bytes, _LF]),
    );
  }

  /// Line feed (LF)
  static PrintCommand lineFeed([int lines = 1]) {
    return RawBytesCommand(
      Uint8List.fromList(List.filled(lines, _LF)),
    );
  }

  /// Form feed (FF)
  static PrintCommand formFeed() {
    return RawBytesCommand(Uint8List.fromList([_FF]));
  }

  /// Horizontal tab (HT)
  static PrintCommand tab() {
    return RawBytesCommand(Uint8List.fromList([_HT]));
  }

  /// Set text alignment (ESC GS a n)
  /// [alignment]: 0 = left, 1 = center, 2 = right
  static PrintCommand setAlignment(int alignment) {
    assert(alignment >= 0 && alignment <= 2);
    return RawBytesCommand(
      Uint8List.fromList([_ESC, _GS, 0x61, alignment]),
    );
  }

  /// Enable emphasized/bold printing (ESC E)
  static PrintCommand enableBold() {
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x45]));
  }

  /// Disable emphasized/bold printing (ESC F)
  static PrintCommand disableBold() {
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x46]));
  }

  /// Enable underline (ESC - n)
  /// [mode]: 0 = off, 1 = 1-dot, 2 = 2-dot
  static PrintCommand setUnderline(int mode) {
    assert(mode >= 0 && mode <= 2);
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x2D, mode]));
  }

  /// Set character size (ESC i n1 n2)
  /// [width]: 0-7 (0 = normal, 1 = 2x, 2 = 3x, etc.)
  /// [height]: 0-7 (0 = normal, 1 = 2x, 2 = 3x, etc.)
  static PrintCommand setCharacterSize(int width, int height) {
    assert(width >= 0 && width <= 7);
    assert(height >= 0 && height <= 7);
    return RawBytesCommand(
      Uint8List.fromList([_ESC, 0x69, width, height]),
    );
  }

  /// Enable double-width mode (ESC W 1)
  static PrintCommand enableDoubleWidth() {
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x57, 0x01]));
  }

  /// Disable double-width mode (ESC W 0)
  static PrintCommand disableDoubleWidth() {
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x57, 0x00]));
  }

  /// Enable double-height mode (ESC h 1)
  static PrintCommand enableDoubleHeight() {
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x68, 0x01]));
  }

  /// Disable double-height mode (ESC h 0)
  static PrintCommand disableDoubleHeight() {
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x68, 0x00]));
  }

  /// Enable inverted printing (white on black) (ESC 4)
  static PrintCommand enableInvert() {
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x34]));
  }

  /// Disable inverted printing (ESC 5)
  static PrintCommand disableInvert() {
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x35]));
  }

  /// Set line spacing (ESC z n)
  /// [n]: line spacing in dots
  static PrintCommand setLineSpacing(int dots) {
    assert(dots >= 0 && dots <= 255);
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x7A, dots]));
  }

  /// Reset line spacing to default (ESC 0)
  static PrintCommand resetLineSpacing() {
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x30]));
  }

  /// Set left margin (ESC l n)
  /// [dots]: left margin in dots
  static PrintCommand setLeftMargin(int dots) {
    assert(dots >= 0 && dots <= 255);
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x6C, dots]));
  }

  /// Set print width (ESC Q n)
  /// [dots]: print width in dots
  static PrintCommand setPrintWidth(int dots) {
    assert(dots >= 0 && dots <= 255);
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x51, dots]));
  }

  /// Cut paper (ESC d n)
  /// [mode]: 0 = full cut, 1 = partial cut
  /// [feedLines]: number of lines to feed before cutting (0-255)
  static PrintCommand cutPaper({int mode = 0, int feedLines = 0}) {
    assert(mode >= 0 && mode <= 1);
    assert(feedLines >= 0 && feedLines <= 255);
    return RawBytesCommand(
      Uint8List.fromList([_ESC, 0x64, (mode << 4) | feedLines]),
    );
  }

  /// Feed paper and cut (convenience method)
  static PrintCommand feedAndCut({int feedLines = 3}) {
    return cutPaper(mode: 0, feedLines: feedLines);
  }

  /// Select character font (ESC RS F n)
  /// [font]: 0 = Font A, 1 = Font B
  static PrintCommand selectFont(int font) {
    assert(font >= 0 && font <= 1);
    return RawBytesCommand(
      Uint8List.fromList([_ESC, 0x1E, 0x46, font]),
    );
  }

  /// Select international character set (ESC R n)
  /// See StarPRNT documentation for character set codes
  static PrintCommand selectCharacterSet(int charset) {
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x52, charset]));
  }

  /// Print and feed paper (ESC J n)
  /// [dots]: number of dots to feed
  static PrintCommand printAndFeed(int dots) {
    assert(dots >= 0 && dots <= 255);
    return RawBytesCommand(Uint8List.fromList([_ESC, 0x4A, dots]));
  }
}

/// Helper class for building complex text layouts
class TextBuilder {
  final CommandSequence _sequence = CommandSequence();

  TextBuilder();

  /// Add text
  TextBuilder text(String text) {
    _sequence.add(TextCommands.printText(text));
    return this;
  }

  /// Add text with line feed
  TextBuilder line(String text) {
    _sequence.add(TextCommands.printLine(text));
    return this;
  }

  /// Add line feed
  TextBuilder feed([int lines = 1]) {
    _sequence.add(TextCommands.lineFeed(lines));
    return this;
  }

  /// Set alignment
  TextBuilder align(int alignment) {
    _sequence.add(TextCommands.setAlignment(alignment));
    return this;
  }

  /// Left align
  TextBuilder left() => align(0);

  /// Center align
  TextBuilder center() => align(1);

  /// Right align
  TextBuilder right() => align(2);

  /// Enable bold
  TextBuilder bold() {
    _sequence.add(TextCommands.enableBold());
    return this;
  }

  /// Disable bold
  TextBuilder normal() {
    _sequence.add(TextCommands.disableBold());
    return this;
  }

  /// Set text size
  TextBuilder size(int width, int height) {
    _sequence.add(TextCommands.setCharacterSize(width, height));
    return this;
  }

  /// Double size text
  TextBuilder doubleSize() => size(1, 1);

  /// Normal size text
  TextBuilder normalSize() => size(0, 0);

  /// Enable underline
  TextBuilder underline([int mode = 1]) {
    _sequence.add(TextCommands.setUnderline(mode));
    return this;
  }

  /// Disable underline
  TextBuilder noUnderline() {
    _sequence.add(TextCommands.setUnderline(0));
    return this;
  }

  /// Cut paper
  TextBuilder cut({int mode = 0, int feedLines = 3}) {
    _sequence.add(TextCommands.cutPaper(mode: mode, feedLines: feedLines));
    return this;
  }

  /// Build the command sequence
  CommandSequence build() {
    return _sequence;
  }

  /// Get the raw bytes
  Uint8List toBytes() {
    return _sequence.toBytes();
  }
}
