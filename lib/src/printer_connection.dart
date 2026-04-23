import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'models/printer_info.dart';
import 'models/print_command.dart';

/// Manages connection and communication with a Star Micronics printer
class PrinterConnection {
  final PrinterInfo printerInfo;
  Socket? _socket;
  bool _isConnected = false;

  PrinterConnection(this.printerInfo);

  /// Check if the printer is currently connected
  bool get isConnected => _isConnected;

  /// Connect to the printer
  Future<void> connect({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_isConnected) {
      return;
    }

    try {
      _socket = await Socket.connect(
        printerInfo.ipAddress,
        printerInfo.port,
        timeout: timeout,
      );
      _isConnected = true;
    } catch (e) {
      throw Exception('Failed to connect to printer: $e');
    }
  }

  /// Disconnect from the printer gracefully (TCP FIN handshake)
  Future<void> disconnect() async {
    if (!_isConnected) {
      return;
    }

    try {
      await _socket?.flush();
      await _socket?.close();
    } catch (e) {
      // Ignore errors during disconnect
    } finally {
      _socket = null;
      _isConnected = false;
    }
  }

  /// Force disconnect using TCP RST (immediate termination).
  /// Use when graceful disconnect fails to release the printer port.
  Future<void> forceDisconnect() async {
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    _isConnected = false;
  }

  /// Send raw bytes to the printer
  Future<void> sendBytes(Uint8List data) async {
    if (!_isConnected || _socket == null) {
      throw Exception('Not connected to printer');
    }

    try {
      _socket!.add(data);
      await _socket!.flush();
    } catch (e) {
      throw Exception('Failed to send data to printer: $e');
    }
  }

  /// Send a single print command
  Future<void> sendCommand(PrintCommand command) async {
    await sendBytes(command.toBytes());
  }

  /// Send a sequence of commands
  Future<void> sendCommandSequence(CommandSequence sequence) async {
    await sendBytes(sequence.toBytes());
  }

  /// Send data and wait for a response
  Future<Uint8List> sendAndReceive(
    Uint8List data, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (!_isConnected || _socket == null) {
      throw Exception('Not connected to printer');
    }

    try {
      _socket!.add(data);
      await _socket!.flush();

      final completer = Completer<Uint8List>();
      final buffer = <int>[];

      late StreamSubscription subscription;
      Timer? timer;

      timer = Timer(timeout, () {
        subscription.cancel();
        if (!completer.isCompleted) {
          completer.completeError(TimeoutException('Response timeout'));
        }
      });

      subscription = _socket!.listen(
        (data) {
          buffer.addAll(data);
        },
        onDone: () {
          timer?.cancel();
          if (!completer.isCompleted) {
            completer.complete(Uint8List.fromList(buffer));
          }
        },
        onError: (error) {
          timer?.cancel();
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      // Wait a bit for data to arrive
      await Future.delayed(const Duration(milliseconds: 500));
      timer?.cancel();
      subscription.cancel();

      if (buffer.isNotEmpty) {
        return Uint8List.fromList(buffer);
      } else {
        throw Exception('No response received from printer');
      }
    } catch (e) {
      throw Exception('Failed to communicate with printer: $e');
    }
  }

  /// Check printer status using ASB (Automatic Status Back)
  /// 
  /// Sends ESC ACK SOH command (0x1B 0x06 0x01) to get real-time status
  Future<PrinterStatus> getStatus() async {
    // StarPRNT ASB status request: ESC ACK SOH
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

  /// Parse ASB (Automatic Status Back) format
  /// 
  /// Based on StarPRNT Appendix 2: Status Specifications
  /// ASB format: [Header1] [Header2] [Status1] [Status2] [Status3] [Status4] [Status5] [Status6] ...
  PrinterStatus _parseASBStatus(Uint8List response) {
    if (response.length < 6) {
      return PrinterStatus(
        isOnline: false,
        errorMessage: 'Invalid status response (too short: ${response.length} bytes)',
      );
    }

    // Header 1 (byte 0): Contains byte count
    // Bit 0 should be 1, bit 4 should be 0 to identify as Header-1
    final header1 = response[0];
    if ((header1 & 0x01) != 0x01 || (header1 & 0x10) == 0x10) {
      return PrinterStatus(
        isOnline: false,
        errorMessage: 'Invalid ASB header',
      );
    }

    // Header 2 (byte 1): Contains version info
    // Not critically needed for basic status

    // Printer Status 1 (byte 2): Basic printer status
    // Bit 3: ONLINE(0)/OFFLINE(1)
    // Bit 5: Cover Open(1)/Closed(0)
    final status1 = response[2];
    final isOnline = (status1 & 0x08) == 0;  // Bit 3: 0 = ONLINE
    final coverOpen = (status1 & 0x20) != 0;  // Bit 5: 1 = OPEN

    // Printer Status 2 (byte 3): Error information
    // Bit 2: Cutter Jam Error
    // Bit 3: Thermal head temperature error
    // Bit 5: Paper end error
    // Bit 6: Paper near-end error
    final status2 = response[3];
    final cutterError = (status2 & 0x04) != 0;
    final headTempError = (status2 & 0x08) != 0;
    final paperEndError = (status2 & 0x20) != 0;
    final paperNearEndError = (status2 & 0x40) != 0;

    // Printer Status 4 (byte 5): Sensor Information
    // Bit 0: Fixed at 0
    // Bit 1: Paper Near-end (Outer Side) - 0 = Paper present, 1 = Paper near-end
    // Bit 2: Paper Near-end (Inner Side) - 0 = Paper present, 1 = Paper near-end  
    // Bit 3: Paper end - 0 = Paper present, 1 = Paper end
    // Bit 4: Fixed at 0
    // Bit 5: Paper Position Error
    final status4 = response.length > 5 ? response[5] : 0;
    final paperEnd = (status4 & 0x08) != 0;           // Bit 3: 1 = no paper
    final paperNearEndInner = (status4 & 0x04) != 0;  // Bit 2: 1 = near end
    final paperNearEndOuter = (status4 & 0x02) != 0;  // Bit 1: 1 = near end
    
    // Paper is present if bit 3 is 0 (not paper end)
    final paperPresent = !paperEnd;

    // Compile error messages
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

  /// Dispose of the connection
  Future<void> dispose() async {
    await disconnect();
  }
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
      parts.add('Raw: ${rawStatus!.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    }
    return parts.join(' | ');
  }

  @override
  String toString() {
    return 'PrinterStatus(online: $isOnline, paper: $paperPresent, error: $hasError${errorMessage != null ? ', msg: $errorMessage' : ''})';
  }
}