import 'dart:typed_data';

import 'models/printer_info.dart';
import 'models/print_command.dart';
import 'transport/native_star_transport.dart';
import 'transport/printer_transport.dart';
import 'transport/tcp_transport.dart';

/// Manages connection and communication with a Star Micronics printer.
///
/// Wraps a [PrinterTransport] (TCP today; USB/Bluetooth via the native plugin
/// soon) and adds StarPRNT-level helpers like ASB status parsing.
class PrinterConnection {
  final PrinterTransport _transport;

  /// Original [PrinterInfo] when this connection was created via the
  /// TCP-friendly constructor. `null` for connections created from a
  /// pre-built transport (e.g. USB or Bluetooth).
  final PrinterInfo? printerInfo;

  /// Build a connection for the printer described by [info].
  ///
  /// The transport is chosen automatically:
  /// - [PrinterConnectionType.tcp] → [TcpTransport] (pure Dart).
  /// - [PrinterConnectionType.usb], [PrinterConnectionType.bluetooth] →
  ///   [NativeStarTransport] (calls Star's native iOS/Android SDK).
  ///
  /// Existing callers passing an IP-only `PrinterInfo` see the same
  /// behavior they always have.
  PrinterConnection(PrinterInfo info)
      : printerInfo = info,
        _transport = _transportFor(info);

  /// Generic constructor accepting any [PrinterTransport] implementation.
  /// Use this for advanced cases (custom transports, tests).
  PrinterConnection.fromTransport(PrinterTransport transport)
      : printerInfo = null,
        _transport = transport;

  static PrinterTransport _transportFor(PrinterInfo info) {
    switch (info.connectionType) {
      case PrinterConnectionType.tcp:
        return TcpTransport(info);
      case PrinterConnectionType.usb:
      case PrinterConnectionType.bluetooth:
        return NativeStarTransport.fromPrinterInfo(info);
    }
  }

  /// Whether the underlying transport is currently connected.
  bool get isConnected => _transport.isConnected;

  /// Connect to the printer.
  Future<void> connect({
    Duration timeout = const Duration(seconds: 5),
  }) =>
      _transport.connect(timeout: timeout);

  /// Disconnect gracefully.
  Future<void> disconnect() => _transport.disconnect();

  /// Force-disconnect (TCP RST equivalent — release the printer immediately).
  Future<void> forceDisconnect() => _transport.forceDisconnect();

  /// Send raw bytes to the printer.
  Future<void> sendBytes(Uint8List data) => _transport.sendBytes(data);

  /// Send a single print command.
  Future<void> sendCommand(PrintCommand command) =>
      sendBytes(command.toBytes());

  /// Send a sequence of commands.
  Future<void> sendCommandSequence(CommandSequence sequence) =>
      sendBytes(sequence.toBytes());

  /// Send data and wait for a response.
  Future<Uint8List> sendAndReceive(
    Uint8List data, {
    Duration timeout = const Duration(seconds: 3),
  }) =>
      _transport.sendAndReceive(data, timeout: timeout);

  /// Check printer status using ASB (Automatic Status Back).
  ///
  /// Sends `ESC ACK SOH` (0x1B 0x06 0x01) to get real-time status.
  Future<PrinterStatus> getStatus() async {
    final statusCommand = Uint8List.fromList([0x1B, 0x06, 0x01]);

    try {
      final response = await sendAndReceive(statusCommand);
      return _parseASBStatus(response);
    } catch (e) {
      return PrinterStatus(
        isOnline: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Parse ASB (Automatic Status Back) format.
  ///
  /// Based on StarPRNT Appendix 2: Status Specifications.
  /// ASB format: [Header1] [Header2] [Status1] [Status2] [Status3] [Status4] [Status5] [Status6] ...
  PrinterStatus _parseASBStatus(Uint8List response) {
    if (response.length < 6) {
      return PrinterStatus(
        isOnline: false,
        errorMessage:
            'Invalid status response (too short: ${response.length} bytes)',
      );
    }

    // Header 1 (byte 0): bit 0 must be 1, bit 4 must be 0.
    final header1 = response[0];
    if ((header1 & 0x01) != 0x01 || (header1 & 0x10) == 0x10) {
      return PrinterStatus(
        isOnline: false,
        errorMessage: 'Invalid ASB header',
      );
    }

    // Printer Status 1 (byte 2): basic printer status.
    final status1 = response[2];
    final isOnline = (status1 & 0x08) == 0; // bit 3: 0 = ONLINE
    final coverOpen = (status1 & 0x20) != 0; // bit 5: 1 = OPEN

    // Printer Status 2 (byte 3): error information.
    final status2 = response[3];
    final cutterError = (status2 & 0x04) != 0;
    final headTempError = (status2 & 0x08) != 0;
    final paperNearEndError = (status2 & 0x40) != 0;

    // Printer Status 4 (byte 5): sensor information.
    final status4 = response.length > 5 ? response[5] : 0;
    final paperEnd = (status4 & 0x08) != 0;
    final paperNearEndInner = (status4 & 0x04) != 0;
    final paperNearEndOuter = (status4 & 0x02) != 0;

    final paperPresent = !paperEnd;

    final errors = <String>[];
    if (!isOnline) errors.add('Printer offline');
    if (coverOpen) errors.add('Cover open');
    if (cutterError) errors.add('Cutter jam');
    if (headTempError) errors.add('Head temperature error');
    if (paperEnd) errors.add('Paper end');
    if (paperNearEndError || paperNearEndInner || paperNearEndOuter) {
      errors.add('Paper near end');
    }

    return PrinterStatus(
      isOnline: isOnline,
      paperPresent: paperPresent,
      paperNearEnd: paperNearEndInner || paperNearEndOuter,
      coverOpen: coverOpen,
      cutterError: cutterError,
      headTempError: headTempError,
      hasError: errors.isNotEmpty,
      errorMessage: errors.isNotEmpty ? errors.join(', ') : null,
      rawStatus: response,
    );
  }

  /// Dispose of the connection.
  Future<void> dispose() => _transport.dispose();
}

/// Represents the status of a printer
class PrinterStatus {
  /// Whether the printer is online
  final bool isOnline;

  /// Whether paper is present (not at paper-end sensor)
  final bool paperPresent;

  /// Whether paper is near end (low paper warning)
  final bool paperNearEnd;

  /// Whether the printer cover is open
  final bool coverOpen;

  /// Whether there's a cutter jam error
  final bool cutterError;

  /// Whether there's a thermal head temperature error
  final bool headTempError;

  /// Whether there's any error condition
  final bool hasError;

  /// Human-readable error message
  final String? errorMessage;

  /// Raw status bytes from printer (for debugging)
  final Uint8List? rawStatus;

  PrinterStatus({
    required this.isOnline,
    this.paperPresent = true,
    this.paperNearEnd = false,
    this.coverOpen = false,
    this.cutterError = false,
    this.headTempError = false,
    this.hasError = false,
    this.errorMessage,
    this.rawStatus,
  });

  /// Get a detailed status report
  String toDetailedString() {
    final parts = <String>[];
    parts.add('Online: $isOnline');
    parts.add('Paper: ${paperPresent ? "Present" : "Out"}');
    if (paperNearEnd) parts.add('Paper Near End: YES');
    if (coverOpen) parts.add('Cover: OPEN');
    if (cutterError) parts.add('Cutter: JAM');
    if (headTempError) parts.add('Head Temp: ERROR');
    if (errorMessage != null) parts.add('Error: $errorMessage');
    if (rawStatus != null) {
      parts.add(
          'Raw: ${rawStatus!.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    }
    return parts.join(' | ');
  }

  @override
  String toString() {
    return 'PrinterStatus(online: $isOnline, paper: $paperPresent, error: $hasError${errorMessage != null ? ', msg: $errorMessage' : ''})';
  }
}
