import 'dart:async';
import 'dart:io';
import 'models/printer_info.dart';

/// Service for discovering Star Micronics printers on the network
class PrinterDiscovery {
  /// Discovers printers on the local network by scanning IP addresses
  ///
  /// [subnet] - The subnet to scan (e.g., '192.168.1')
  /// [startRange] - Starting IP address in the range (default: 1)
  /// [endRange] - Ending IP address in the range (default: 254)
  /// [port] - Port to check (default: 9100 for Star printers)
  /// [timeout] - Connection timeout duration (default: 2 seconds)
  ///
  /// Returns a stream of discovered printers
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

    // Process results as they complete
    for (final future in futures) {
      final printer = await future;
      if (printer != null) {
        yield printer;
      }
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
      socket = await Socket.connect(
        ipAddress,
        port,
        timeout: timeout,
      );

      // If connection successful, this is likely a printer
      return PrinterInfo(
        ipAddress: ipAddress,
        port: port,
      );
    } catch (e) {
      // Connection failed, no printer at this address
      return null;
    } finally {
      socket?.destroy();
    }
  }

  /// Discovers printers by broadcasting (mDNS/Bonjour)
  ///
  /// Note: This requires platform-specific implementation and additional dependencies
  /// For now, this is a placeholder for future implementation
  static Stream<PrinterInfo> discoverByBroadcast({
    Duration timeout = const Duration(seconds: 5),
  }) async* {
    // TODO: Implement mDNS discovery
    // This would require packages like multicast_dns
    throw UnimplementedError('Broadcast discovery not yet implemented');
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
          // Look for IPv4 addresses that aren't loopback
          if (addr.type == InternetAddressType.IPv4 && 
              !addr.isLoopback) {
            final parts = addr.address.split('.');
            if (parts.length == 4) {
              // Return the first three octets
              return '${parts[0]}.${parts[1]}.${parts[2]}';
            }
          }
        }
      }
    } catch (e) {
      // Ignore errors
    }
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

    yield* discover(
      subnet: subnet,
      timeout: timeout,
    );
  }
}
