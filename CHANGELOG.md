## 1.1.0

* USB and Bluetooth Classic transports on iOS and Android via Star Micronics' native SDK (`com.starmicronics:stario` on Android, `StarIO.framework` + `StarIO_Extension.framework` on iOS).
* iOS MFi External Accessory support inherited from the bundled `StarIO.framework` — no MFi membership required by the host app, but `UISupportedExternalAccessoryProtocols` must be added to the host app's `Info.plist`.
* `PrinterDiscovery.discoverNative()` discovers USB and Bluetooth printers via the native SDK.
* `PrinterInfo.usb()` and `PrinterInfo.bluetooth()` constructors; `PrinterInfo.fromNativeMap()` for round-tripping native discovery payloads.
* New `PrinterTransport` abstraction with `TcpTransport` (pure Dart) and `NativeStarTransport` (USB/Bluetooth via method channel).
* No breaking changes — existing TCP code (`PrinterInfo(ipAddress: ...)` / `PrinterConnection(printer)`) is unchanged.

## 1.0.0

* Initial release
* Network printer discovery
* Text printing with formatting
* Raster graphics printing
* QR code generation
* Barcode printing (1D and PDF417)
* Printer status checking
* Command builder utilities
* Full StarPRNT protocol support
