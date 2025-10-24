# Font Preparation Guide for RasterImageBuilder

## ✅ Best Practice: Multiple Font Sizes

**Create separate bitmap font files for each size you'll use.**

### Why Not Scale?
- ❌ Scaling bitmap fonts = pixelated, blurry text
- ❌ Loss of hinting optimizations
- ❌ Poor quality on thermal printers
- ✅ Each size optimized for that specific point size

## 📁 Recommended Font Structure

```
assets/fonts/
  ├── arial/
  │   ├── arial_10.zip    # 10pt - small labels
  │   ├── arial_12.zip    # 12pt - body text
  │   ├── arial_16.zip    # 16pt - emphasis
  │   ├── arial_24.zip    # 24pt - headers
  │   └── arial_36.zip    # 36pt - titles
  ├── roboto/
  │   ├── roboto_12.zip
  │   ├── roboto_16.zip
  │   └── roboto_24.zip
  └── courier/
      ├── courier_10.zip   # Monospace for codes
      └── courier_12.zip
```

## 🔧 Converting TTF to Bitmap Fonts

### Option 1: BMFont (Recommended)
Download: http://www.angelcode.com/products/bmfont/

**Steps:**
1. Open BMFont
2. Options → Font Settings
   - Select your TTF font
   - Set charset (Unicode is best)
   - Set font size (e.g., 12, 16, 24, etc.)
3. Options → Export Options
   - Bit depth: 8
   - Texture width/height: 256 or 512
   - Font descriptor: XML (.fnt)
   - Texture: PNG
4. Options → Save bitmap font as...
   - Creates .fnt and .png files
5. **Zip them together**: `arial_12.zip` containing `arial_12.fnt` and `arial_12_0.png`

**Repeat for each size you need!**

### Option 2: ShoeBox (Mac/Windows/Linux)
Download: http://renderhjs.net/shoebox/

1. Drag TTF into ShoeBox
2. Select "Bitmap Font" tool
3. Configure size and export settings
4. Export as zip

### Option 3: Hiero (Cross-platform, Java-based)
Download: https://github.com/libgdx/libgdx/wiki/Hiero

1. Load TTF font
2. Set font size
3. Select character ranges
4. Render and export
5. Zip the .fnt and .png files

### Option 4: Command Line (fontbm)
```bash
# Install fontbm
brew install fontbm  # macOS
# or build from source

# Convert font
fontbm --font-file arial.ttf \
       --font-size 16 \
       --output arial_16

# Zip the results
zip arial_16.zip arial_16.fnt arial_16.png
```

## 📊 Recommended Sizes for Receipts

### Standard Receipt (80mm paper, 203 DPI)

| Size | Use Case | Example |
|------|----------|---------|
| 10pt | Fine print, legal text | Terms & conditions |
| 12pt | Body text, items | Product names, prices |
| 14pt | Subheadings | Section headers |
| 16pt | Emphasis | Totals, important info |
| 20pt | Headers | Store name |
| 24pt | Large headers | "RECEIPT", "INVOICE" |
| 36pt | Titles | Promotional text |

### Minimal Set (3 sizes)
- **12pt** - Body text
- **16pt** - Emphasis
- **24pt** - Headers

### Standard Set (5 sizes)
- **10pt** - Fine print
- **12pt** - Body text
- **16pt** - Subheaders
- **24pt** - Headers
- **36pt** - Titles

## 💾 Font File Size Considerations

Approximate sizes for bitmap fonts:

| Size | Characters | File Size |
|------|-----------|-----------|
| 10pt | ASCII (128) | ~15 KB |
| 12pt | ASCII (128) | ~20 KB |
| 16pt | ASCII (128) | ~30 KB |
| 24pt | ASCII (128) | ~50 KB |
| 12pt | Extended (256) | ~40 KB |
| 24pt | Unicode subset (500) | ~150 KB |

**Tip**: Only include characters you actually need to keep file sizes small.

## 🎯 Using Fonts in Code

### Load and Use Different Sizes

```dart
final img = RasterImageBuilder(384, 200);

// Small text (10pt)
await img.drawText('Terms apply', 
  x: 10, y: 180,
  fontPath: 'assets/fonts/arial/arial_10.zip',
  size: 10,
);

// Body text (12pt)
await img.drawText('Coffee - Grande',
  x: 10, y: 50,
  fontPath: 'assets/fonts/arial/arial_12.zip',
  size: 12,
);

// Header (24pt)
await img.drawText('RECEIPT',
  x: 100, y: 10,
  fontPath: 'assets/fonts/arial/arial_24.zip',
  size: 24,
  bold: true,
);

// Large title (36pt)
await img.drawText('SALE',
  x: 150, y: 100,
  fontPath: 'assets/fonts/arial/arial_36.zip',
  size: 36,
);
```

### Font Manager Helper

Create a helper class to manage fonts:

```dart
class FontManager {
  static const fontDir = 'assets/fonts';
  
  static String arial(int size) => '$fontDir/arial/arial_$size.zip';
  static String roboto(int size) => '$fontDir/roboto/roboto_$size.zip';
  static String courier(int size) => '$fontDir/courier/courier_$size.zip';
}

// Usage
await img.drawText('Hello',
  x: 10, y: 10,
  fontPath: FontManager.arial(16),
  size: 16,
);
```

## 🔍 Character Set Recommendations

### ASCII Only (128 characters)
- Smallest file size
- English-only
- Numbers, basic punctuation

### Extended ASCII (256 characters)
- Western European languages
- Common symbols
- Good balance of size/coverage

### Unicode Subset
- Specific language support
- Emoji if needed
- Can be large (MB range)

**For thermal receipts**: ASCII or Extended ASCII is usually sufficient.

## ⚡ Performance Tips

1. **Preload fonts at app start**
   ```dart
   // Load commonly used fonts once
   await RasterImageBuilder._preloadFont('assets/fonts/arial_12.zip');
   await RasterImageBuilder._preloadFont('assets/fonts/arial_16.zip');
   ```

2. **Cache is automatic** - Fonts are cached after first load

3. **Use fewer sizes** - Each size = separate file to load

4. **ASCII only** - Smaller files load faster

## 🐛 Troubleshooting

### "Font file not found"
- Check file path is correct
- Ensure font is in assets and listed in `pubspec.yaml`
- Use absolute path or path relative to working directory

### Text looks pixelated
- You're probably scaling a bitmap font
- Create a separate font file at the exact size needed

### Missing characters appear as boxes
- Character not in font file
- Include that character when generating bitmap font
- Or use a font with broader character coverage

### Text too large/small
- Using wrong font size file
- Match the font file size to the `size` parameter
- Don't rely on scaling

## 📝 pubspec.yaml Setup

```yaml
flutter:
  assets:
    - assets/fonts/arial/
    - assets/fonts/roboto/
    - assets/fonts/courier/
```

## 🎨 Font Styles

### Bold
Create separate bold font files:
```
arial_12.zip       # Regular
arial_12_bold.zip  # Bold
```

Or use the `bold` parameter (renders twice with offset):
```dart
await img.drawText('Bold',
  fontPath: 'assets/fonts/arial/arial_12.zip',
  bold: true,  // Simulated bold
);
```

### Italic
Create separate italic font files:
```
arial_12.zip        # Regular
arial_12_italic.zip # Italic
```

## 🚀 Quick Start Checklist

- [ ] Download BMFont or similar tool
- [ ] Convert your TTF fonts at these sizes: 12pt, 16pt, 24pt
- [ ] Zip each .fnt + .png pair
- [ ] Place in `assets/fonts/` directory
- [ ] Add to `pubspec.yaml`
- [ ] Use exact size files (no scaling)
- [ ] Test on actual thermal printer

## 📚 Additional Resources

- BMFont: http://www.angelcode.com/products/bmfont/
- Hiero: https://github.com/libgdx/libgdx/wiki/Hiero
- ShoeBox: http://renderhjs.net/shoebox/
- fontbm: https://github.com/vladimirgamalyan/fontbm
- Image package docs: https://pub.dev/packages/image

---

**Remember**: One size file per font size = best quality! 📝✨
