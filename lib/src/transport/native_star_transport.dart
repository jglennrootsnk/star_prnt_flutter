import 'package:flutter/services.dart';

import '../models/printer_info.dart';
import 'printer_transport.dart';

/// Settings string passed to Star's native SDK when opening a port.
///
/// Star uses this hint to select status parsing behavior. Values:
///   - `""`             — Star Line Mode desktop (default)
///   - `"Portable"`     — Star Line portable
///   - `"Portable;ESCPOS"` — ESC/POS portable
///   - `"mini"`         — ESC/POS mobile (matches Star's StarPRNT mapping)
///   - `"escpos"`       — ESC/POS desktop
///   - `"Portable;l"`   — StarPRNT portable
///
/// For typical TCP/9100 raw-byte usage these don't affect what's printed;
/// they only influence Star's internal status interpretation.
class StarPortSettings {
  static const String none = '';
  static const String portable = 'Portable';
  static const String portableEscPos = 'Portable;ESCPOS';
  static const String escPosMobile = 'mini';
  static const String escPos = 'escpos';
  static const String starPrntPortable = 'Portable;l';
}

/// Transport that talks to Star printers via the platform's native SDK,
/// used for USB and Bluetooth (and optionally TCP).
///
/// Bytes flow over a [MethodChannel] to a Kotlin/Swift shim that owns the
/// native [`StarIOPort`/`SMPort`] handle. StarPRNT command construction
/// stays in Dart — this transport only moves bytes.
class NativeStarTransport implements PrinterTransport {
  /// Shared with the native side. Don't instantiate per-printer; one channel
  /// serves any number of concurrent connections (each keyed by handle).
  static const MethodChannel _channel =
      MethodChannel('star_prnt_flutter/native');

  /// Native port name (e.g. `"USB:TSP100"`, `"BT:00:11:62:..."`).
  final String portName;

  /// Star port settings hint (see [StarPortSettings]). Most apps using
  /// pure-Dart StarPRNT command building can leave this at the default.
  final String portSettings;

  String? _handle;

  NativeStarTransport({
    required this.portName,
    this.portSettings = StarPortSettings.none,
  });

  /// Convenience constructor from a [PrinterInfo] (USB or Bluetooth).
  factory NativeStarTransport.fromPrinterInfo(
    PrinterInfo info, {
    String portSettings = StarPortSettings.none,
  }) {
    final name = info.portName;
    if (name == null || name.isEmpty) {
      throw ArgumentError(
        'PrinterInfo has no native portName; '
        'use the .usb()/.bluetooth() constructors or PrinterInfo.fromNativeMap.',
      );
    }
    return NativeStarTransport(portName: name, portSettings: portSettings);
  }

  @override
  bool get isConnected => _handle != null;

  @override
  Future<void> connect({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_handle != null) return;
    try {
      final handle = await _channel.invokeMethod<String>('open', {
        'portName': portName,
        'portSettings': portSettings,
        'timeoutMillis': timeout.inMilliseconds,
      });
      if (handle == null) {
        throw Exception('Native open returned null handle');
      }
      _handle = handle;
    } on PlatformException catch (e) {
      throw Exception('Failed to open $portName: ${e.message ?? e.code}');
    }
  }

  @override
  Future<void> disconnect() async {
    final h = _handle;
    if (h == null) return;
    _handle = null;
    try {
      await _channel.invokeMethod('close', {'handle': h});
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<void> forceDisconnect() => disconnect();

  /// Maximum bytes per native write call. Bluetooth has limited buffer space
  /// and throughput — sending large payloads (e.g. raster labels) in one shot
  /// can overflow the printer's receive buffer, causing truncated prints.
  static const int _maxChunkSize = 1024;

  /// Delay between chunks to let the Bluetooth/USB transport drain.
  static const Duration _interChunkDelay = Duration(milliseconds: 60);

  @override
  Future<void> sendBytes(Uint8List data) async {
    final h = _handle;
    if (h == null) {
      throw Exception('Not connected to printer');
    }
    try {
      // Chunk large payloads to avoid overwhelming Bluetooth/USB buffers
      if (data.length <= _maxChunkSize) {
        await _channel.invokeMethod('write', {
          'handle': h,
          'bytes': data,
        });
      } else {
        for (var offset = 0; offset < data.length; offset += _maxChunkSize) {
          final end = (offset + _maxChunkSize).clamp(0, data.length);
          final chunk = data.sublist(offset, end);
          await _channel.invokeMethod('write', {
            'handle': h,
            'bytes': chunk,
          });
          // Allow the transport buffer to drain between chunks
          if (end < data.length) {
            await Future.delayed(_interChunkDelay);
          }
        }
      }
    } on PlatformException catch (e) {
      throw Exception('Failed to send data: ${e.message ?? e.code}');
    }
  }

  @override
  Future<Uint8List> sendAndReceive(
    Uint8List data, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    await sendBytes(data);
    // Star's native read is non-blocking and returns whatever's already in the
    // buffer. Poll briefly to give the printer time to respond.
    final deadline = DateTime.now().add(timeout);
    final accumulated = <int>[];
    while (DateTime.now().isBefore(deadline)) {
      final chunk = await _readOnce(maxLength: 1024);
      if (chunk.isNotEmpty) {
        accumulated.addAll(chunk);
        // Status responses are small; once we've started receiving, give a
        // brief grace period for the rest, then return.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final tail = await _readOnce(maxLength: 1024);
        accumulated.addAll(tail);
        return Uint8List.fromList(accumulated);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (accumulated.isEmpty) {
      throw Exception('No response received from printer');
    }
    return Uint8List.fromList(accumulated);
  }

  Future<Uint8List> _readOnce({int maxLength = 1024}) async {
    final h = _handle;
    if (h == null) return Uint8List(0);
    try {
      final result = await _channel.invokeMethod('read', {
        'handle': h,
        'maxLength': maxLength,
      });
      if (result is Uint8List) return result;
      if (result is List) return Uint8List.fromList(result.cast<int>());
      return Uint8List(0);
    } on PlatformException {
      return Uint8List(0);
    }
  }

  /// Pull Star's parsed status structure from the native side.
  ///
  /// Returns a map with bool keys: `offline`, `coverOpen`, `overTemp`,
  /// `cutterError`, `receiptPaperEmpty`. Useful for transports where the
  /// raw ASB request isn't reliable (e.g. some Bluetooth flows).
  Future<Map<String, bool>> getNativeStatus() async {
    final h = _handle;
    if (h == null) {
      throw Exception('Not connected to printer');
    }
    final result = await _channel.invokeMethod('getStatus', {'handle': h});
    final map = Map<String, dynamic>.from(result as Map);
    return map.map((k, v) => MapEntry(k, v == true));
  }

  /// Star firmware information (model name, firmware version).
  Future<Map<String, String>> getFirmwareInformation() async {
    final h = _handle;
    if (h == null) {
      throw Exception('Not connected to printer');
    }
    final result =
        await _channel.invokeMethod('getFirmwareInformation', {'handle': h});
    final map = Map<String, dynamic>.from(result as Map);
    return map.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }

  @override
  Future<void> dispose() => disconnect();
}
