# Star PRNT Flutter Test Guide

This guide explains how to test the Star PRNT Flutter package functionality using the included main function.

## Running the Test

1. **Open Terminal** and navigate to the project directory:
   ```bash
   cd /path/to/flutter_star
   ```

2. **Run the test**:
   ```bash
   dart run lib/main.dart
   ```

## What the Test Does

The test program performs the following operations:

### 1. Printer Discovery
- Automatically scans your local network for Star Micronics printers
- Shows all discovered printers with their IP addresses
- Also tries common subnets if local discovery doesn't find anything

### 2. Interactive Testing
If you provide a printer IP address, the test will perform:

- **Connection Test**: Verifies connectivity and printer status
- **Basic Text Printing**: Tests simple text output with formatting
- **Formatted Receipt**: Creates a professional receipt using TextBuilder
- **Graphics Commands**: Tests QR codes and barcodes
- **Raster Graphics**: Tests bitmap image printing

## Example Output

```
=== Star PRNT Flutter Test ===

--- Test 1: Printer Discovery ---
Discovering printers on local network...
Found printer: 192.168.1.100:9100
Found printer: 192.168.1.200:9100
Discovery complete. Found 2 printer(s)

To test printing functionality:
Enter printer IP address (or press Enter to skip printer tests):
IP address: 192.168.1.100

--- Test 2: Printer Connection ---
Connecting to printer at 192.168.1.100...
✓ Connected successfully
Status: PrinterStatus(online: true, paper: true, error: false)
Disconnected from printer

--- Test 3: Basic Text Printing ---
✓ Basic printing test completed

--- Test 4: Formatted Receipt ---
✓ Formatted receipt printed

--- Test 5: Graphics Commands ---
✓ Graphics commands completed

--- Test 6: Raster Graphics ---
✓ Raster graphics completed

=== Test Complete ===
```

## Testing Without a Printer

You can run the test without a physical printer to:
- Test the discovery functionality
- Verify that all APIs compile and load correctly
- See the structure of the commands being generated

Just press Enter when prompted for a printer IP address.

## Manual Testing with Specific IP

If you know your printer's IP address, you can directly enter it when prompted:
- Standard Star printers typically use port 9100
- Common IP ranges: 192.168.1.x, 192.168.0.x, 10.0.0.x
- Check your router's admin panel or printer settings for the exact IP

## Test Features Covered

The test demonstrates all major features from the quickstart guide:

### Printer Discovery
- ✅ `PrinterDiscovery.discoverLocal()`
- ✅ `PrinterDiscovery.discover()` with specific subnet
- ✅ `PrinterDiscovery.isPrinterOnline()`

### Basic Connection
- ✅ `PrinterConnection()` creation
- ✅ `connect()` and `disconnect()`
- ✅ `getStatus()` for printer status

### Text Commands
- ✅ Basic text printing with `TextCommands`
- ✅ Text formatting (bold, alignment, size)
- ✅ Line feeds and paper cutting
- ✅ `TextBuilder` fluent API

### Graphics Commands
- ✅ QR code printing with `GraphicsCommands.printQRCode()`
- ✅ Barcode printing with various formats
- ✅ Test patterns

### Raster Graphics
- ✅ Bitmap creation and printing
- ✅ `RasterImageBuilder` for custom graphics
- ✅ Geometric shapes and patterns

## Troubleshooting

### No Printers Found
- Ensure the printer is connected to the same network
- Check that the printer's network settings are configured
- Verify the printer is powered on and ready
- Try specifying a specific subnet if auto-discovery fails

### Connection Errors
- Verify the IP address is correct
- Check that port 9100 is not blocked by firewall
- Ensure the printer supports network printing
- Try pinging the printer IP first: `ping 192.168.1.100`

### Print Quality Issues
- Check paper is loaded correctly
- Verify printer has sufficient paper
- Clean the print head if text appears faded
- Adjust print density settings if available

## API Examples in Code

The test main function serves as a comprehensive example of how to use every major API in the Star PRNT Flutter package. You can copy and modify the test functions for your own applications.

Each test function demonstrates best practices like:
- Proper connection management with try/finally
- Error handling and status checking
- Command sequence building
- Resource cleanup

## Next Steps

After running the test successfully:
1. Review the source code in `lib/main.dart` to understand the API usage
2. Check out the `QUICKSTART.md` for more focused examples
3. Refer to the `example/example.dart` for additional use cases
4. Build your own printing functionality using the patterns shown