import 'package:flutter_test/flutter_test.dart';
import 'package:star_prnt_flutter/star_prnt_flutter.dart';

void main() {
  group('PrinterInfo', () {
    test('creates printer info correctly', () {
      final printer = PrinterInfo(
        ipAddress: '192.168.1.100',
        port: 9100,
        modelName: 'TSP100',
      );

      expect(printer.ipAddress, '192.168.1.100');
      expect(printer.port, 9100);
      expect(printer.modelName, 'TSP100');
    });

    test('uses default port when not specified', () {
      final printer = PrinterInfo(ipAddress: '192.168.1.100');
      expect(printer.port, 9100);
    });

    test('equality works correctly', () {
      final printer1 = PrinterInfo(ipAddress: '192.168.1.100');
      final printer2 = PrinterInfo(ipAddress: '192.168.1.100');
      final printer3 = PrinterInfo(ipAddress: '192.168.1.101');

      expect(printer1, equals(printer2));
      expect(printer1, isNot(equals(printer3)));
    });
  });

  group('TextCommands', () {
    test('initialize command generates correct bytes', () {
      final cmd = TextCommands.initialize();
      final bytes = cmd.toBytes();
      expect(bytes, [0x1B, 0x40]);
    });

    test('printLine adds line feed', () {
      final cmd = TextCommands.printLine('Test');
      final bytes = cmd.toBytes();
      expect(bytes.last, 0x0A); // LF
    });

    test('setAlignment generates correct command', () {
      final cmd = TextCommands.setAlignment(1);
      final bytes = cmd.toBytes();
      expect(bytes, [0x1B, 0x1D, 0x61, 0x01]);
    });

    test('enableBold generates correct command', () {
      final cmd = TextCommands.enableBold();
      final bytes = cmd.toBytes();
      expect(bytes, [0x1B, 0x45]);
    });
  });

  group('CommandSequence', () {
    test('combines multiple commands', () {
      final sequence = CommandSequence();
      sequence.add(TextCommands.enableBold());
      sequence.add(TextCommands.printText('Test'));

      expect(sequence.length, 2);
      
      final bytes = sequence.toBytes();
      expect(bytes.length, greaterThan(0));
    });

    test('clear removes all commands', () {
      final sequence = CommandSequence();
      sequence.add(TextCommands.enableBold());
      sequence.add(TextCommands.printText('Test'));
      
      sequence.clear();
      expect(sequence.length, 0);
    });
  });

  group('TextBuilder', () {
    test('builds command sequence correctly', () {
      final builder = TextBuilder()
          .center()
          .bold()
          .line('Test')
          .normal();

      final sequence = builder.build();
      expect(sequence.length, greaterThan(0));
    });

    test('chaining works correctly', () {
      final builder = TextBuilder();
      
      final result = builder
          .center()
          .bold()
          .line('Test');

      expect(result, same(builder)); // Should return same instance
    });
  });

  group('RasterCommands', () {
    test('bitmapToRaster converts correctly', () {
      final bitmap = [
        [true, false, true, false, true, false, true, false],
        [false, true, false, true, false, true, false, true],
      ];

      final raster = RasterCommands.bitmapToRaster(bitmap);
      
      expect(raster.length, 2); // 2 rows, 1 byte each
      expect(raster[0], 0xAA); // 10101010
      expect(raster[1], 0x55); // 01010101
    });

    test('throws on empty bitmap', () {
      expect(
        () => RasterCommands.bitmapToRaster([]),
        throwsArgumentError,
      );
    });

    test('throws on inconsistent width', () {
      final bitmap = [
        [true, false],
        [true, false, true], // Different width
      ];

      expect(
        () => RasterCommands.bitmapToRaster(bitmap),
        throwsArgumentError,
      );
    });
  });

  group('RasterImageBuilder', () {
    test('creates image with correct dimensions', () {
      final builder = RasterImageBuilder(100, 50);
      final bitmap = builder.getBitmap();

      expect(bitmap.length, 50); // height
      expect(bitmap[0].length, 100); // width
    });

    test('setPixel works correctly', () {
      final builder = RasterImageBuilder(10, 10);
      builder.setPixel(5, 5, value: 0); // 0 = black

      final bitmap = builder.getBitmap();
      expect(bitmap[5][5], true); // Black pixel (< 128 threshold)
      expect(bitmap[0][0], false); // White background pixels
      
      // Test pixel reading
      expect(builder.getPixel(5, 5), 0); // Black
      expect(builder.getPixel(0, 0), 255); // White
    });

    test('fillRect fills correctly', () {
      final builder = RasterImageBuilder(10, 10);
      builder.fillRect(2, 2, 3, 3, color: 0); // Black fill

      final bitmap = builder.getBitmap();
      
      // Check filled area (should be black/true)
      expect(bitmap[2][2], true);
      expect(bitmap[3][3], true);
      expect(bitmap[4][4], true);
      
      // Check outside area (should be white/false)
      expect(bitmap[0][0], false);
      expect(bitmap[5][5], false);
    });

    test('rotation parameter works correctly', () {
      // Test that rotation values are accepted
      expect(() => RasterImageBuilder(100, 50, rotation: 0), returnsNormally);
      expect(() => RasterImageBuilder(100, 50, rotation: 90), returnsNormally);
      expect(() => RasterImageBuilder(100, 50, rotation: 180), returnsNormally);
      expect(() => RasterImageBuilder(100, 50, rotation: 270), returnsNormally);
      
      // Test that invalid rotation throws
      expect(
        () => RasterImageBuilder(100, 50, rotation: 45),
        throwsArgumentError,
      );
    });

    test('rounded rectangle parameters work', () {
      final builder = RasterImageBuilder(100, 100);
      
      // Should not throw with valid parameters
      expect(
        () => builder.fillRect(10, 10, 50, 50, radius: 10),
        returnsNormally,
      );
      
      // Independent corner radii
      expect(
        () => builder.fillRect(10, 10, 50, 50,
          topLeft: 5,
          topRight: 10,
          bottomLeft: 15,
          bottomRight: 20,
        ),
        returnsNormally,
      );
    });

    test('drawCircle works', () {
      final builder = RasterImageBuilder(100, 100);
      
      expect(
        () => builder.drawCircle(50, 50, 20, thickness: 2),
        returnsNormally,
      );
    });

    test('fillCircle works', () {
      final builder = RasterImageBuilder(100, 100);
      
      expect(
        () => builder.fillCircle(50, 50, 20, color: 0),
        returnsNormally,
      );
    });

    test('drawLine works', () {
      final builder = RasterImageBuilder(100, 100);
      
      expect(
        () => builder.drawLine(0, 0, 99, 99, thickness: 2, color: 0),
        returnsNormally,
      );
    });

    test('invert works', () {
      final builder = RasterImageBuilder(20, 20);
      builder.fillRect(5, 5, 10, 10, color: 0);
      
      // Invert the entire image
      expect(() => builder.invert(), returnsNormally);
      
      // After inversion, center should be white, outside should be black
      final bitmap = builder.getBitmap();
      expect(bitmap[10][10], false); // Was black, now white
      expect(bitmap[0][0], true); // Was white, now black
    });

    test('clear works', () {
      final builder = RasterImageBuilder(20, 20);
      builder.fillRect(5, 5, 10, 10, color: 0);
      
      // Clear to white
      builder.clear(color: 255);
      
      final bitmap = builder.getBitmap();
      expect(bitmap[10][10], false); // All white
      expect(bitmap[0][0], false);
    });

    test('drawImage composition works', () {
      final main = RasterImageBuilder(100, 100);
      final stamp = RasterImageBuilder(20, 20);
      
      stamp.fillCircle(10, 10, 8);
      
      expect(
        () => main.drawImage(stamp, 40, 40),
        returnsNormally,
      );
    });
  });

  group('GraphicsCommands', () {
    test('printQRCode generates correct command structure', () {
      final cmd = GraphicsCommands.printQRCode(
        data: 'Test',
        cellSize: 3,
      );
      
      final bytes = cmd.toBytes();
      expect(bytes.length, greaterThan(0));
      
      // Check for ESC GS sequences
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x1D);
    });

    test('printBarcode generates correct command', () {
      final cmd = GraphicsCommands.printBarcode(
        data: '123456',
        type: GraphicsCommands.barcodeTypeCODE39,
      );
      
      final bytes = cmd.toBytes();
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x62); // 'b' command
    });
  });
}
