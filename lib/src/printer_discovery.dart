import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'models/printer_info.dart';

/// Filter for [PrinterDiscovery.discoverNative].
enum NativeDiscoveryTarget {
  /// All transports the native SDK knows about.
  all,

  /// Bluetooth Classic / MFi (paired devices on iOS, paired devices on Android).
  bluetooth,

  /// USB printers — USB-B printer class on Android, MFi USB iAP on iOS.
  usb,

  /// LAN printers visible to Star's native discovery.
  lan,
}

/// Service for discovering Star Micronics printers.
///
/// Two discovery paths are exposed:
/// - [discover] / [discoverLocal] — pure-Dart subnet scan for TCP/9100 printers
///   (the original behavior, still useful when you want quick LAN discovery
///   without the native SDK).
/// - [discoverNative] — calls Star's native SDK on iOS/Android to find USB and
///   Bluetooth printers (and LAN, if you'd prefer Star's discovery). Required
///   for any non-TCP transport.
class PrinterDiscovery {
  static const MethodChannel _channel =
      MethodChannel('star_prnt_flutter/native');

  /// Discovers printers on the local network by scanning IP addresses
  /// for an open TCP port (typically 9100).
  ///
  /// Pure-Dart implementation; works on every platform without the native
  /// SDK. For USB or Bluetooth discovery, use [discoverNative] instead.
  static Stream<PrinterInfo> discover({
    required String subnet,
    int startRange = 1,
    int endRange = 254,
    int port = 9100,
    Duration timeout = const Duration(seconds: 2),
  }) async* {
    final futures = <Future<PrinterInfo?>>[];

    for (var i = startRange; i <= endRange; i++) {
      final ipAddress = '$subnet.$i';
      futures.add(_checkPrinter(ipAddress, port, timeout));
    }

    for (final future in futures) {
      final printer = await future;
      if (printer != null) yield printer;
    }
  }

  /// Discover Bluetooth, USB, and LAN printers via Star's native SDK.
  ///
  /// Only available on iOS and Android. On other platforms this returns
  /// an empty list (it does not throw, so calling code can be transport-
  /// agnostic).
  ///
  /// On iOS, Bluetooth printers must already be paired in Settings — Apple
  /// does not let third-party apps initiate MFi pairing.
  static Future<List<PrinterInfo>> discoverNative({
    NativeDiscoveryTarget target = NativeDiscoveryTarget.all,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) return const [];
    try {
      final result = await _channel.invokeMethod('searchPrinters', {
        'target': target.name.toUpperCase(),
      });
      if (result is! List) return const [];
      return result
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(PrinterInfo.fromNativeMap)
          .toList();
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Checks if a printer is available at the given address
  static Future<PrinterInfo?> _checkPrinter(
    String ipAddress,
    int port,
    Duration timeout,
  ) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ipAddress, port, timeout: timeout);
      return PrinterInfo(ipAddress: ipAddress, port: port);
    } catch (_) {
      return null;
    } finally {
      socket?.destroy();
    }
  }

  /// Checks if a specific printer is online
  static Future<bool> isPrinterOnline(
    String ipAddress, {
    int port = 9100,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final printer = await _checkPrinter(ipAddress, port, timeout);
    return printer != null;
  }

  /// Gets the local subnet by examining network interfaces
  static Future<String?> getLocalSubnet() async {
    try {
      final interfaces = await NetworkInterface.list();

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              return '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Convenience method to discover printers on the local network
  static Stream<PrinterInfo> discoverLocal({
    Duration timeout = const Duration(seconds: 2),
  }) async* {
    final subnet = await getLocalSubnet();
    if (subnet == null) {
      throw Exception('Unable to determine local subnet');
    }
    yield* discover(subnet: subnet, timeout: timeout);
  }
}
