/// Which physical transport a [PrinterInfo] describes.
enum PrinterConnectionType {
  /// Network printer over TCP (typically port 9100).
  tcp,

  /// USB printer (USB-B printer class on Android, USB iAP on iOS).
  usb,

  /// Bluetooth Classic, via MFi External Accessory on iOS.
  bluetooth,
}

/// Information about a Star Micronics printer.
///
/// One model serves all transports:
/// - **TCP**: requires [ipAddress] (and optionally [port], default 9100).
/// - **USB / Bluetooth**: requires [portName] in Star's native format
///   (e.g. `"USB:TSP100"` or `"BT:00:11:62:..."`). These come back from
///   `PrinterDiscovery.discoverNative`.
class PrinterInfo {
  /// Transport this printer is reached over.
  final PrinterConnectionType connectionType;

  /// IP address (TCP only).
  final String ipAddress;

  /// TCP port. Star printers default to 9100.
  final int port;

  /// Native port name reported by Star's SDK. Required for USB and Bluetooth;
  /// not used for TCP.
  final String? portName;

  /// Optional printer model name if detected.
  final String? modelName;

  /// Optional MAC address.
  final String? macAddress;

  /// Optional USB serial number (USB transport, Android only).
  final String? usbSerialNumber;

  /// TCP/ethernet printer. The original constructor — unchanged so existing
  /// callers continue to work.
  const PrinterInfo({
    required this.ipAddress,
    this.port = 9100,
    this.modelName,
    this.macAddress,
  })  : connectionType = PrinterConnectionType.tcp,
        portName = null,
        usbSerialNumber = null;

  /// USB printer. [portName] must be the value returned by Star's SDK
  /// (typically prefixed with `"USB:"`).
  const PrinterInfo.usb({
    required String this.portName,
    this.modelName,
    this.usbSerialNumber,
  })  : connectionType = PrinterConnectionType.usb,
        ipAddress = '',
        port = 0,
        macAddress = null;

  /// Bluetooth (Classic / MFi) printer. [portName] must be the value
  /// returned by Star's SDK (typically prefixed with `"BT:"`).
  const PrinterInfo.bluetooth({
    required String this.portName,
    this.modelName,
    this.macAddress,
  })  : connectionType = PrinterConnectionType.bluetooth,
        ipAddress = '',
        port = 0,
        usbSerialNumber = null;

  /// Construct from the native plugin's discovery payload.
  factory PrinterInfo.fromNativeMap(Map<String, dynamic> map) {
    final name = (map['portName'] as String?) ?? '';
    final upper = name.toUpperCase();
    if (upper.startsWith('BT:')) {
      return PrinterInfo.bluetooth(
        portName: name,
        modelName: _nullIfEmpty(map['modelName'] as String?),
        macAddress: _nullIfEmpty(map['macAddress'] as String?),
      );
    }
    if (upper.startsWith('USB:')) {
      return PrinterInfo.usb(
        portName: name,
        modelName: _nullIfEmpty(map['modelName'] as String?),
        usbSerialNumber: _nullIfEmpty(map['usbSerialNumber'] as String?),
      );
    }
    // Fallback: treat as TCP. The native side returns "TCP:<ip>" — strip prefix.
    final ip = upper.startsWith('TCP:') ? name.substring(4) : name;
    return PrinterInfo(
      ipAddress: ip,
      modelName: _nullIfEmpty(map['modelName'] as String?),
      macAddress: _nullIfEmpty(map['macAddress'] as String?),
    );
  }

  static String? _nullIfEmpty(String? s) => (s == null || s.isEmpty) ? null : s;

  @override
  String toString() {
    switch (connectionType) {
      case PrinterConnectionType.tcp:
        return 'PrinterInfo(tcp $ipAddress:$port${modelName != null ? ', model: $modelName' : ''})';
      case PrinterConnectionType.usb:
        return 'PrinterInfo(usb $portName${modelName != null ? ', model: $modelName' : ''})';
      case PrinterConnectionType.bluetooth:
        return 'PrinterInfo(bt $portName${modelName != null ? ', model: $modelName' : ''})';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterInfo &&
          runtimeType == other.runtimeType &&
          connectionType == other.connectionType &&
          ipAddress == other.ipAddress &&
          port == other.port &&
          portName == other.portName;

  @override
  int get hashCode =>
      connectionType.hashCode ^
      ipAddress.hashCode ^
      port.hashCode ^
      (portName?.hashCode ?? 0);
}
