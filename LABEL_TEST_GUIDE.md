# Label Generation Test Guide

## Overview

Added `testLabelGeneration()` function to `lib/main.dart` that demonstrates the complete label printing workflow using the `LabelGenerator` helper and bitmap fonts from the `./fonts` directory.

## Test Function

The `testLabelGeneration()` function:
- Uses all 7 Quicksand bitmap fonts from `./fonts/`
- Generates a 3" × 2" food order label at 300 DPI
- Prints in landscape orientation with 270° rotation
- Demonstrates the complete label layout:
  - Top row: Logo, customer name, platform icon
  - Horizontal divider line
  - Item title with index (e.g., "(2 of 4) El Jefe Bowl")
  - Wrapped ingredient list
  - Bottom row: Three rounded boxes for Order#, Eat before date, and Order type
- **Mock Mode**: Can save label as PNG instead of printing

## Mock Mode

When the `mock` parameter is set to `true`, the label will be saved as a PNG file instead of being sent to the printer:

```dart
// Save to file instead of printing
await testLabelGeneration(printerIp, mock: true);
```

The image will be saved to:
- Directory: `./label-output/`
- Filename: `label-{timestamp}.png` (e.g., `label-2025-10-24T14-30-45-123456.png`)
- Format: Grayscale PNG showing the label before rotation and thresholding

This is useful for:
- Testing label generation without a printer
- Debugging layout issues
- Previewing labels before printing
- Generating mockups for documentation

## Fonts Used

The test uses the following fonts from `./fonts/`:
- **Quicksand-Regular-18px.zip** - For ingredient text and labels
- **Quicksand-Regular-24px.zip** - For date information
- **Quicksand-Bold-32px.zip** - For order numbers and type
- **Quicksand-Bold-48px.zip** - For customer name and item titles

Note: The generator expects a 72px font, but we're reusing the 48px font for now. Add `Quicksand-Bold-72px.zip` if needed.

## Required Assets

The label generator references these icon files (update paths as needed):
- `./icons/doordash.png` - Platform icon (top-right)
- `./icons/logo.png` - Logo (top-left, optional)

If these icons don't exist, the test will catch the error and print a warning, but the label will still generate without them.

## Running the Test

1. Ensure your printer is connected and the IP address is set in `main.dart`
2. Make sure the font files exist in `./fonts/`
3. Run the main.dart file:
   ```bash
   dart lib/main.dart
   ```
   or
   ```bash
   flutter run -d macos
   ```

4. The test will print a complete food order label demonstrating:
   - Multiple font sizes and weights
   - Text wrapping for long ingredient lists
   - Rounded rectangle borders
   - Proper spacing and alignment
   - 270° rotation for portrait label orientation

## Sample Output

The test prints a label for a sample order:
- Customer: Colin G
- Item: (2 of 4) El Jefe Bowl
- Order: 9678039
- Eat before: 10/11/2025
- Type: Delivery
- Ingredients: Brown Rice, Kale, Avocado, etc. (wrapped text)

## Code Integration

The test is integrated into the main test suite:
- Located in `lib/main.dart` as Test 7
- Called from the main() function
- Uses the same connection pattern as other tests
- Includes proper error handling and cleanup

## Next Steps

To customize the label:
1. Edit the sample data in `testLabelGeneration()`
2. Adjust font sizes by using different fonts from `./fonts/`
3. Add your own logo and platform icons to `./icons/`
4. Modify layout constants in `LabelGenerator.generateLabel()` if needed
5. Change label dimensions by editing `labelWidth` and `labelHeight` in the generator

## Troubleshooting

**"Could not load logo/icon"**: The icon files don't exist at the specified paths. Either create them or comment out the logo/icon references.

**Font errors**: Ensure all `.zip` font files are in the `./fonts/` directory and match the exact filenames used in the test.

**Label doesn't print**: Check printer connection, paper width (3" required), and printer compatibility.

**Text appears too small/large**: The label is designed for 300 DPI at 3" width. Adjust font sizes or label dimensions if your printer has different specifications.
