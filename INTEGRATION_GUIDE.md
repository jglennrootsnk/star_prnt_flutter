# Integration Guide - Star PRNT Flutter Package

## Quick Integration into Your Project

### Option 1: Local Package (Recommended for Development)

1. **Copy the package to your project**:
   ```bash
   cp -r star_prnt_flutter /path/to/your/project/packages/
   ```

2. **Add to your pubspec.yaml**:
   ```yaml
   dependencies:
     star_prnt_flutter:
       path: ./packages/star_prnt_flutter
   ```

3. **Run pub get**:
   ```bash
   flutter pub get
   ```

### Option 2: Publish to pub.dev

1. Update `pubspec.yaml` with your details
2. Run: `dart pub publish --dry-run`
3. Run: `dart pub publish`
4. Use in projects: `star_prnt_flutter: ^1.0.0`

### Option 3: Git Repository

1. Push to Git repository
2. In your pubspec.yaml:
   ```yaml
   dependencies:
     star_prnt_flutter:
       git:
         url: https://github.com/yourusername/star_prnt_flutter.git
         ref: main
   ```

## Basic Integration Example

### 1. Create a Printer Service

```dart
// lib/services/printer_service.dart
import 'package:star_prnt_flutter/star_prnt_flutter.dart';

class PrinterService {
  PrinterConnection? _connection;
  
  Future<List<PrinterInfo>> discoverPrinters() async {
    final printers = <PrinterInfo>[];
    await for (final printer in PrinterDiscovery.discoverLocal()) {
      printers.add(printer);
    }
    return printers;
  }
  
  Future<void> connect(PrinterInfo printer) async {
    _connection = PrinterConnection(printer);
    await _connection!.connect();
  }
  
  Future<void> disconnect() async {
    await _connection?.disconnect();
    _connection = null;
  }
  
  Future<bool> isConnected() async {
    if (_connection == null) return false;
    try {
      final status = await _connection!.getStatus();
      return status.isOnline;
    } catch (e) {
      return false;
    }
  }
  
  Future<void> printReceipt(ReceiptData data) async {
    if (_connection == null) {
      throw Exception('Not connected to printer');
    }
    
    final receipt = TextBuilder()
        .center()
        .bold()
        .line(data.storeName)
        .normal()
        .line(data.storeAddress)
        .feed()
        .left();
    
    for (final item in data.items) {
      receipt.line('${item.name}     \$${item.price}');
    }
    
    receipt
        .feed()
        .right()
        .bold()
        .line('TOTAL: \$${data.total}')
        .feed(2)
        .cut();
    
    await _connection!.sendCommandSequence(receipt.build());
  }
}

class ReceiptData {
  final String storeName;
  final String storeAddress;
  final List<ReceiptItem> items;
  final double total;
  
  ReceiptData({
    required this.storeName,
    required this.storeAddress,
    required this.items,
    required this.total,
  });
}

class ReceiptItem {
  final String name;
  final double price;
  
  ReceiptItem({required this.name, required this.price});
}
```

### 2. Create a Printer Selection Screen

```dart
// lib/screens/printer_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:star_prnt_flutter/star_prnt_flutter.dart';
import '../services/printer_service.dart';

class PrinterSelectionScreen extends StatefulWidget {
  @override
  _PrinterSelectionScreenState createState() => _PrinterSelectionScreenState();
}

class _PrinterSelectionScreenState extends State<PrinterSelectionScreen> {
  final PrinterService _printerService = PrinterService();
  List<PrinterInfo> _printers = [];
  bool _isScanning = false;
  
  @override
  void initState() {
    super.initState();
    _scanForPrinters();
  }
  
  Future<void> _scanForPrinters() async {
    setState(() => _isScanning = true);
    
    try {
      final printers = await _printerService.discoverPrinters();
      setState(() {
        _printers = printers;
        _isScanning = false;
      });
    } catch (e) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error scanning: $e')),
      );
    }
  }
  
  Future<void> _connectToPrinter(PrinterInfo printer) async {
    try {
      await _printerService.connect(printer);
      
      if (await _printerService.isConnected()) {
        Navigator.pop(context, printer);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect to printer')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection error: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Printer'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isScanning ? null : _scanForPrinters,
          ),
        ],
      ),
      body: _isScanning
          ? Center(child: CircularProgressIndicator())
          : _printers.isEmpty
              ? Center(child: Text('No printers found'))
              : ListView.builder(
                  itemCount: _printers.length,
                  itemBuilder: (context, index) {
                    final printer = _printers[index];
                    return ListTile(
                      leading: Icon(Icons.print),
                      title: Text(printer.ipAddress),
                      subtitle: Text('Port: ${printer.port}'),
                      trailing: Icon(Icons.chevron_right),
                      onTap: () => _connectToPrinter(printer),
                    );
                  },
                ),
    );
  }
}
```

### 3. Use in Your App

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'screens/printer_selection_screen.dart';
import 'services/printer_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Printer Demo',
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  final PrinterService _printerService = PrinterService();
  
  Future<void> _selectAndPrint(BuildContext context) async {
    final printer = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PrinterSelectionScreen()),
    );
    
    if (printer != null) {
      await _printTestReceipt();
    }
  }
  
  Future<void> _printTestReceipt() async {
    final receiptData = ReceiptData(
      storeName: 'My Store',
      storeAddress: '123 Main St',
      items: [
        ReceiptItem(name: 'Coffee', price: 3.50),
        ReceiptItem(name: 'Muffin', price: 2.50),
      ],
      total: 6.00,
    );
    
    try {
      await _printerService.printReceipt(receiptData);
      // Show success message
    } catch (e) {
      // Show error message
    } finally {
      await _printerService.disconnect();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Printer Demo')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => _selectAndPrint(context),
          child: Text('Print Receipt'),
        ),
      ),
    );
  }
}
```

## Common Customizations

### 1. Adjust for Your Printer Model

Check your printer's emulation mode in the PDF spec and adjust if needed:
```dart
// Most printers use StarPRNT or StarGraphic
// No changes needed if using the default commands
```

### 2. Custom Paper Width

```dart
// For 58mm paper (common for mobile printers)
final imageWidth = 384; // dots at 8 dots/mm

// For 80mm paper
final imageWidth = 576; // full width
final imageWidth = 512; // with margins
```

### 3. Add Your Logo

```dart
Future<void> printWithLogo() async {
  // Load your logo bitmap
  final logoBitmap = await loadLogoBitmap();
  
  final commands = CommandSequence();
  commands.add(TextCommands.setAlignment(1));
  
  // Print logo
  final logoRaster = RasterCommands.bitmapToRaster(logoBitmap);
  commands.add(RasterCommands.printRasterGraphics(
    imageData: logoRaster,
    width: logoBitmap[0].length,
    height: logoBitmap.length,
  ));
  
  commands.add(TextCommands.feed());
  // ... rest of receipt
}
```

### 4. Implement Retry Logic

```dart
Future<void> printWithRetry(CommandSequence commands, {int maxRetries = 3}) async {
  for (var i = 0; i < maxRetries; i++) {
    try {
      await _connection!.sendCommandSequence(commands);
      return;
    } catch (e) {
      if (i == maxRetries - 1) rethrow;
      await Future.delayed(Duration(seconds: 1));
    }
  }
}
```

## Troubleshooting

### Printer Not Found
```dart
// Try specifying exact IP
final printer = PrinterInfo(ipAddress: '192.168.1.100');
final online = await PrinterDiscovery.isPrinterOnline(printer.ipAddress);
```

### Print Quality Issues
```dart
// Use dithering for images
final dithered = RasterCommands.ditherImage(
  imageData: grayscalePixels,
  width: width,
  height: height,
);
```

### Connection Timeout
```dart
// Increase timeout
await connection.connect(timeout: Duration(seconds: 10));
```

## Performance Tips

1. **Reuse Connections**: Keep connection open for multiple prints
2. **Batch Commands**: Use CommandSequence for multiple operations
3. **Optimize Images**: Reduce image size before converting to raster
4. **Cache Discovery**: Store discovered printers, don't scan every time

## Security Considerations

1. **Network Access**: Request appropriate permissions
2. **User Input**: Validate printer IP addresses
3. **Error Messages**: Don't expose sensitive network info to users
4. **Timeout**: Set reasonable timeouts to prevent hanging

## Platform-Specific Notes

### Android
Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### iOS
Add to `Info.plist`:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app needs to find printers on your network</string>
```

### Web
Note: Web has CORS limitations. For web support, you may need a proxy server.

## Next Steps

1. Test with your actual printer
2. Adjust commands if needed based on your printer model
3. Implement your specific receipt/label layout
4. Add error handling for your use case
5. Consider adding local storage for printer settings

## Support

Reference the StarPRNT specification PDF included with your package for detailed command information.
