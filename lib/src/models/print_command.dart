import 'dart:typed_data';

/// Base class for all print commands
abstract class PrintCommand {
  /// Convert this command to ESC/POS bytes
  Uint8List toBytes();
}

/// A command containing raw bytes
class RawBytesCommand extends PrintCommand {
  final Uint8List bytes;

  RawBytesCommand(this.bytes);

  @override
  Uint8List toBytes() => bytes;
}

/// Represents a sequence of print commands
class CommandSequence {
  final List<PrintCommand> _commands = [];

  /// Add a command to the sequence
  void add(PrintCommand command) {
    _commands.add(command);
  }

  /// Add multiple commands
  void addAll(List<PrintCommand> commands) {
    _commands.addAll(commands);
  }

  /// Add raw bytes
  void addRaw(Uint8List bytes) {
    _commands.add(RawBytesCommand(bytes));
  }

  /// Convert all commands to a single byte array
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

  /// Get the number of commands in the sequence
  int get length => _commands.length;

  /// Clear all commands
  void clear() {
    _commands.clear();
  }
}
