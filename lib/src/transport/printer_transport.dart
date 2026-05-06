import 'dart:typed_data';

/// Transport-level interface for talking to a Star Micronics printer.
///
/// Implementations include [TcpTransport] (pure Dart, ethernet) and
/// (planned) `NativeStarTransport` (USB and Bluetooth via Star's native SDK).
abstract class PrinterTransport {
  /// Whether this transport currently has an open connection.
  bool get isConnected;

  /// Open the connection. Idempotent: safe to call when already connected.
  Future<void> connect({Duration timeout = const Duration(seconds: 5)});

  /// Close the connection gracefully.
  Future<void> disconnect();

  /// Force the connection closed without waiting for a graceful handshake.
  Future<void> forceDisconnect();

  /// Send raw bytes. Throws if not connected.
  Future<void> sendBytes(Uint8List data);

  /// Send bytes and read whatever the printer returns within [timeout].
  Future<Uint8List> sendAndReceive(
    Uint8List data, {
    Duration timeout = const Duration(seconds: 3),
  });

  /// Release any resources. Should imply [disconnect].
  Future<void> dispose();
}
