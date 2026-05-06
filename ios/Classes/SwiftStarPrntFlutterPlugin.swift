import Flutter
import UIKit
import StarIO

/// Native bridge for USB and Bluetooth Star printer connections on iOS.
///
/// Mirrors the Android plugin: `searchPrinters` / `open` / `write` / `read`
/// / `close` (plus `getStatus` / `getFirmwareInformation`). All command
/// construction and ASB status parsing live in Dart — this class only moves
/// bytes across the platform boundary.
///
/// Star's `StarIO.framework` carries the MFi protocol registrations
/// (`jp.star-m.starpro` and `jp.star-m.starpro.ext`) that allow the iOS
/// External Accessory framework to open Bluetooth Classic and USB sessions
/// to certified Star printers without the host app needing its own MFi
/// agreement.
@objc(SwiftStarPrntFlutterPlugin)
public class SwiftStarPrntFlutterPlugin: NSObject, FlutterPlugin {
    private static let channelName = "star_prnt_flutter/native"
    private let workQueue = DispatchQueue(
        label: "com.rootsnk.flutter_star.work",
        qos: .userInitiated,
        attributes: .concurrent
    )

    /// Live ports keyed by handle. Star's SMPort is not thread-safe, so a
    /// per-handle serial queue would be safer if we expected concurrent
    /// write/read on the same handle — but Dart-side we only ever issue one
    /// at a time.
    private var ports: [String: SMPort] = [:]
    private let portsLock = NSLock()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = SwiftStarPrntFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let safeResult: FlutterResult = { value in
            DispatchQueue.main.async { result(value) }
        }

        workQueue.async { [weak self] in
            guard let self = self else { return }
            switch call.method {
            case "searchPrinters":     self.searchPrinters(call, safeResult)
            case "open":               self.open(call, safeResult)
            case "close":              self.close(call, safeResult)
            case "write":              self.write(call, safeResult)
            case "read":               self.read(call, safeResult)
            case "getStatus":          self.getStatus(call, safeResult)
            case "getFirmwareInformation": self.getFirmwareInformation(call, safeResult)
            default:                   safeResult(FlutterMethodNotImplemented)
            }
        }
    }

    // MARK: - Handle storage

    private func storePort(_ port: SMPort) -> String {
        let handle = UUID().uuidString
        portsLock.lock()
        defer { portsLock.unlock() }
        ports[handle] = port
        return handle
    }

    private func getPort(_ handle: String) -> SMPort? {
        portsLock.lock()
        defer { portsLock.unlock() }
        return ports[handle]
    }

    private func removePort(_ handle: String) -> SMPort? {
        portsLock.lock()
        defer { portsLock.unlock() }
        return ports.removeValue(forKey: handle)
    }

    // MARK: - Method handlers

    private func searchPrinters(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let target = (args["target"] as? String ?? "ALL").uppercased()

        let targets: [String]
        switch target {
        case "ALL":                 targets = ["BT:", "TCP:", "USB:"]
        case "BLUETOOTH", "BT":     targets = ["BT:"]
        case "LAN", "TCP":          targets = ["TCP:"]
        case "USB":                 targets = ["USB:"]
        default:                    targets = [target]
        }

        var infos: [[String: Any]] = []
        for t in targets {
            do {
                let found = try SMPort.searchPrinter(target: t)
                for raw in found {
                    if let info = raw as? PortInfo {
                        infos.append(portInfoToMap(info))
                    }
                }
            } catch {
                // A single transport failing (e.g. Bluetooth off) shouldn't
                // poison the result; ignore and keep going.
            }
        }
        result(infos)
    }

    private func open(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let portName = args["portName"] as? String else {
            result(FlutterError(code: "ARG", message: "portName required", details: nil))
            return
        }
        let portSettings = args["portSettings"] as? String ?? ""
        let timeoutMillis = UInt32(args["timeoutMillis"] as? Int ?? 10000)

        do {
            let port = try SMPort.getPort(
                portName: portName,
                portSettings: portSettings,
                ioTimeoutMillis: timeoutMillis
            )
            // Bluetooth ports need a brief settle after open; mirrors the
            // sibling plugin's behavior. Cheap on USB/TCP, important on BT.
            if portName.uppercased().hasPrefix("BT:") {
                usleep(200_000) // 0.2 s
            }
            let handle = storePort(port)
            result(handle)
        } catch {
            result(FlutterError(code: "OPEN_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func close(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let handle = args["handle"] as? String else {
            result(FlutterError(code: "ARG", message: "handle required", details: nil))
            return
        }
        if let port = removePort(handle) {
            SMPort.release(port)
        }
        result(nil)
    }

    private func write(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let handle = args["handle"] as? String,
              let port = getPort(handle) else {
            result(FlutterError(code: "CLOSED", message: "handle not open", details: nil))
            return
        }
        guard let data = args["bytes"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "ARG", message: "bytes required", details: nil))
            return
        }
        let bytes = [UInt8](data.data)
        do {
            var total: UInt32 = 0
            let length = UInt32(bytes.count)
            while total < length {
                var written: UInt32 = 0
                try port.write(
                    writeBuffer: bytes,
                    offset: total,
                    size: length - total,
                    numberOfBytesWritten: &written
                )
                if written == 0 { break }
                total += written
            }
            result(Int(total))
        } catch {
            result(FlutterError(code: "WRITE_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func read(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let handle = args["handle"] as? String,
              let port = getPort(handle) else {
            result(FlutterError(code: "CLOSED", message: "handle not open", details: nil))
            return
        }
        let maxLen = UInt32(args["maxLength"] as? Int ?? 1024)
        var buffer = [UInt8](repeating: 0, count: Int(maxLen))
        do {
            var read: UInt32 = 0
            try port.read(
                readBuffer: &buffer,
                offset: 0,
                size: maxLen,
                numberOfBytesRead: &read
            )
            let slice = Data(buffer.prefix(Int(read)))
            result(FlutterStandardTypedData(bytes: slice))
        } catch {
            result(FlutterError(code: "READ_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func getStatus(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let handle = args["handle"] as? String,
              let port = getPort(handle) else {
            result(FlutterError(code: "CLOSED", message: "handle not open", details: nil))
            return
        }
        var status = StarPrinterStatus_2()
        do {
            try port.getParsedStatus(starPrinterStatus: &status, level: 2)
            // SM_BOOLEAN is a typedef for u_int32_t; SM_TRUE == 1.
            // Comparing against 0 is equivalent and avoids depending on
            // header constants that aren't reliably exposed to Swift.
            result([
                "offline": status.offline != 0,
                "coverOpen": status.coverOpen != 0,
                "overTemp": status.overTemp != 0,
                "cutterError": status.cutterError != 0,
                "receiptPaperEmpty": status.receiptPaperEmpty != 0
            ])
        } catch {
            result(FlutterError(code: "STATUS_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func getFirmwareInformation(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        guard let handle = args["handle"] as? String,
              let port = getPort(handle) else {
            result(FlutterError(code: "CLOSED", message: "handle not open", details: nil))
            return
        }
        do {
            let firmware = try port.getFirmwareInformation()
            var out: [String: String] = [:]
            for (k, v) in firmware {
                if let key = k as? String, let val = v as? String { out[key] = val }
            }
            result(out)
        } catch {
            result(FlutterError(code: "FIRMWARE_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    // MARK: - Helpers

    private func portInfoToMap(_ info: PortInfo) -> [String: Any] {
        return [
            "portName": info.portName ?? "",
            "macAddress": info.macAddress ?? "",
            "modelName": info.modelName ?? "",
            "usbSerialNumber": ""
        ]
    }
}
