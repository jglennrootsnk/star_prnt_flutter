/// Information about a discovered Star Micronics printer
class PrinterInfo {
  /// The IP address of the printer
  final String ipAddress;

  /// The port number (typically 9100 for Star printers)
  final int port;

  /// Optional printer model name if detected
  final String? modelName;

  /// Optional MAC address
  final String? macAddress;

  PrinterInfo({
    required this.ipAddress,
    this.port = 9100,
    this.modelName,
    this.macAddress,
  });

  @override
  String toString() {
    return 'PrinterInfo(ip: $ipAddress:$port${modelName != null ? ', model: $modelName' : ''})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterInfo &&
          runtimeType == other.runtimeType &&
          ipAddress == other.ipAddress &&
          port == other.port;

  @override
  int get hashCode => ipAddress.hashCode ^ port.hashCode;
}
