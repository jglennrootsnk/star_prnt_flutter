/// A Flutter package for Star Micronics thermal printers
///
/// Provides discovery and printing capabilities for Star Micronics thermal
/// printers using the StarPRNT protocol over Ethernet (TCP), USB, and
/// Bluetooth (USB and Bluetooth via Star's native SDK on iOS and Android).
library star_prnt_flutter;

export 'src/models/printer_info.dart';
export 'src/models/print_command.dart';
export 'src/printer_discovery.dart';
export 'src/printer_connection.dart';
export 'src/transport/printer_transport.dart';
export 'src/transport/tcp_transport.dart';
export 'src/transport/native_star_transport.dart';
export 'src/commands/text_commands.dart';
export 'src/commands/raster_commands.dart';
export 'src/commands/graphics_commands.dart';
