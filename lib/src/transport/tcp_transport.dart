import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../models/printer_info.dart';
import 'printer_transport.dart';

/// Ethernet (TCP raw socket) transport, typically port 9100.
class TcpTransport implements PrinterTransport {
  final PrinterInfo printerInfo;
  Socket? _socket;
  bool _isConnected = false;

  TcpTransport(this.printerInfo);

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> connect({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_isConnected) return;

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

  @override
  Future<void> disconnect() async {
    if (!_isConnected) return;

    try {
      await _socket?.flush();
      await _socket?.close();
    } catch (_) {
      // Ignore errors during disconnect
    } finally {
      _socket = null;
      _isConnected = false;
    }
  }

  @override
  Future<void> forceDisconnect() async {
    try {
      _socket?.destroy();
    } catch (_) {}
    _socket = null;
    _isConnected = false;
  }

  @override
  Future<void> sendBytes(Uint8List data) async {
    if (!_isConnected || _socket == null) {
      throw Exception('Not connected to printer');
    }

    try {
      _socket!.add(data);
      await _socket!.flush();
    } catch (e) {
      _isConnected = false;
      throw Exception('Failed to send data to printer: $e');
    }
  }

  @override
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

      final buffer = <int>[];
      final subscription = _socket!.listen(
        buffer.addAll,
        onError: (_) {},
      );

      // Give the printer a moment to respond.
      await Future.delayed(const Duration(milliseconds: 500));
      await subscription.cancel();

      if (buffer.isEmpty) {
        throw Exception('No response received from printer');
      }
      return Uint8List.fromList(buffer);
    } catch (e) {
      throw Exception('Failed to communicate with printer: $e');
    }
  }

  @override
  Future<void> dispose() => disconnect();
}
