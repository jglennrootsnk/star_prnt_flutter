package com.rootsnk.flutter_star

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.starmicronics.stario.PortInfo
import com.starmicronics.stario.StarIOPort
import com.starmicronics.stario.StarPrinterStatus
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Native bridge for USB and Bluetooth Star printer connections.
 *
 * Exposes a small handle-based transport: open() returns a String handle,
 * which the Dart side passes back into write()/read()/close(). The native
 * code keeps a map of handles to live [StarIOPort] objects.
 *
 * StarPRNT byte construction and ASB status parsing remain in Dart; this
 * class only moves bytes across the platform boundary.
 */
class StarPrntFlutterPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val ports = ConcurrentHashMap<String, StarIOPort>()
    private val executor = Executors.newCachedThreadPool()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        // Best-effort cleanup of any leaked ports.
        for (port in ports.values) {
            try { StarIOPort.releasePort(port) } catch (_: Exception) {}
        }
        ports.clear()
    }

    override fun onMethodCall(call: MethodCall, rawResult: Result) {
        val result = MainThreadResult(rawResult)
        executor.execute {
            try {
                when (call.method) {
                    "searchPrinters" -> searchPrinters(call, result)
                    "open" -> open(call, result)
                    "close" -> close(call, result)
                    "write" -> write(call, result)
                    "read" -> read(call, result)
                    "getStatus" -> getStatus(call, result)
                    "getFirmwareInformation" -> getFirmwareInformation(call, result)
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("UNHANDLED", e.message ?: e.javaClass.simpleName, null)
            }
        }
    }

    private fun searchPrinters(call: MethodCall, result: Result) {
        val target = (call.argument<String>("target") ?: "ALL").uppercase()
        val out = mutableListOf<Map<String, Any?>>()

        val targets = when (target) {
            "ALL" -> listOf("BT:", "TCP:", "USB:")
            "BLUETOOTH", "BT" -> listOf("BT:")
            "LAN", "TCP" -> listOf("TCP:")
            "USB" -> listOf("USB:")
            else -> listOf(target)
        }

        for (t in targets) {
            try {
                val list = if (t.startsWith("USB"))
                    StarIOPort.searchPrinter(t, context)
                else
                    StarIOPort.searchPrinter(t)
                for (info in list) out.add(portInfoToMap(info))
            } catch (_: Exception) {
                // A single transport failing (e.g. Bluetooth disabled) shouldn't
                // poison the whole result.
            }
        }
        result.success(out)
    }

    private fun open(call: MethodCall, result: Result) {
        val portName = call.argument<String>("portName")
            ?: return result.error("ARG", "portName required", null)
        val portSettings = call.argument<String>("portSettings") ?: ""
        val timeout = call.argument<Int>("timeoutMillis") ?: 10000

        try {
            val port = StarIOPort.getPort(portName, portSettings, timeout, context)
            // Brief settle: matches the sibling plugin's behavior so the first
            // operation after open doesn't race the socket.
            Thread.sleep(200)
            val handle = UUID.randomUUID().toString()
            ports[handle] = port
            result.success(handle)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    private fun close(call: MethodCall, result: Result) {
        val handle = call.argument<String>("handle")
            ?: return result.error("ARG", "handle required", null)
        val port = ports.remove(handle)
        if (port != null) {
            try { StarIOPort.releasePort(port) } catch (_: Exception) {}
        }
        result.success(null)
    }

    private fun write(call: MethodCall, result: Result) {
        val handle = call.argument<String>("handle")
            ?: return result.error("ARG", "handle required", null)
        val bytes = call.argument<ByteArray>("bytes")
            ?: return result.error("ARG", "bytes required", null)
        val port = ports[handle]
            ?: return result.error("CLOSED", "handle not open", null)

        try {
            var offset = 0
            while (offset < bytes.size) {
                val written = port.writePort(bytes, offset, bytes.size - offset)
                if (written <= 0) break
                offset += written
            }
            result.success(offset)
        } catch (e: Exception) {
            result.error("WRITE_FAILED", e.message, null)
        }
    }

    private fun read(call: MethodCall, result: Result) {
        val handle = call.argument<String>("handle")
            ?: return result.error("ARG", "handle required", null)
        val maxLen = call.argument<Int>("maxLength") ?: 1024
        val port = ports[handle]
            ?: return result.error("CLOSED", "handle not open", null)

        try {
            val buffer = ByteArray(maxLen)
            val read = port.readPort(buffer, 0, maxLen)
            result.success(if (read <= 0) ByteArray(0) else buffer.copyOf(read))
        } catch (e: Exception) {
            result.error("READ_FAILED", e.message, null)
        }
    }

    private fun getStatus(call: MethodCall, result: Result) {
        val handle = call.argument<String>("handle")
            ?: return result.error("ARG", "handle required", null)
        val port = ports[handle]
            ?: return result.error("CLOSED", "handle not open", null)

        try {
            val status: StarPrinterStatus = port.retreiveStatus()
            result.success(mapOf(
                "offline" to status.offline,
                "coverOpen" to status.coverOpen,
                "overTemp" to status.overTemp,
                "cutterError" to status.cutterError,
                "receiptPaperEmpty" to status.receiptPaperEmpty
            ))
        } catch (e: Exception) {
            result.error("STATUS_FAILED", e.message, null)
        }
    }

    private fun getFirmwareInformation(call: MethodCall, result: Result) {
        val handle = call.argument<String>("handle")
            ?: return result.error("ARG", "handle required", null)
        val port = ports[handle]
            ?: return result.error("CLOSED", "handle not open", null)

        try {
            val firmware: Map<String, String> = port.firmwareInformation
            result.success(firmware)
        } catch (e: Exception) {
            result.error("FIRMWARE_FAILED", e.message, null)
        }
    }

    private fun portInfoToMap(info: PortInfo): Map<String, Any?> {
        val portName = if (info.portName.startsWith("BT:"))
            "BT:" + info.macAddress
        else
            info.portName
        return mapOf(
            "portName" to portName,
            "macAddress" to (info.macAddress ?: ""),
            "modelName" to (info.modelName ?: ""),
            "usbSerialNumber" to (info.usbSerialNumber ?: "")
        )
    }

    /**
     * Forwards Result callbacks to the main thread. The Star SDK calls happen
     * on a worker thread, but Flutter's MethodChannel requires Result calls
     * back on the platform thread.
     */
    private class MainThreadResult(private val raw: Result) : Result {
        private val handler = Handler(Looper.getMainLooper())
        override fun success(r: Any?) { handler.post { raw.success(r) } }
        override fun error(code: String, message: String?, details: Any?) {
            handler.post { raw.error(code, message, details) }
        }
        override fun notImplemented() { handler.post { raw.notImplemented() } }
    }

    companion object {
        private const val CHANNEL_NAME = "star_prnt_flutter/native"
    }
}
