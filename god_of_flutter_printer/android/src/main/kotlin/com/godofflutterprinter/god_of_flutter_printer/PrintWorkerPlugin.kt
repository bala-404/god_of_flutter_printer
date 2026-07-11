package com.godofflutterprinter.god_of_flutter_printer

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.IOException
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors
import java.util.regex.Pattern

/** Android USB/BT bridge for God of Flutter Printer. */
class PrintWorkerPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private var bluetoothSocket: BluetoothSocket? = null
    private var usbConnection: UsbDeviceConnection? = null
    private var usbOutEndpoint: UsbEndpoint? = null
    private var connectedUsbDevice: UsbDevice? = null
    private val ioExecutor = Executors.newCachedThreadPool()

    companion object {
        private const val CHANNEL = "com.godofflutterprinter/platform"
        private val SPP_UUID: UUID =
            UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        private val PRODUCT_ID_SUFFIX = Pattern.compile("\\[(\\d+)\\]\\s*$")
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        disconnectBluetooth()
        disconnectUsb()
        ioExecutor.shutdownNow()
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "listUsbPrinters" -> listUsbPrinters(result)
            "listBluetoothDevices" -> listBluetoothDevices(result)
            "bluetoothConnect" -> connectBluetooth(call, result)
            "bluetoothWrite" -> writeBluetooth(call, result)
            "bluetoothDisconnect" -> {
                disconnectBluetooth()
                result.success(null)
            }
            "usbConnect" -> connectUsb(call, result)
            "usbWrite" -> writeUsb(call, result)
            "usbDisconnect" -> {
                disconnectUsb()
                result.success(null)
            }
            "bleConnect", "bleWrite", "bleDisconnect" ->
                result.error(
                    "not_implemented",
                    "BLE printing on Android is not implemented yet. Use Bluetooth Classic.",
                    null,
                )
            else -> result.notImplemented()
        }
    }

    private fun usbManager(): UsbManager =
        appContext.getSystemService(Context.USB_SERVICE) as UsbManager

    private fun listUsbPrinters(result: Result) {
        try {
            val deviceList = usbManager().deviceList
            val printers = deviceList.values.map { device ->
                val name = device.productName ?: device.deviceName
                "$name [${device.productId}]"
            }
            result.success(printers)
        } catch (e: Exception) {
            result.error("usb_list_failed", e.message, null)
        }
    }

    private fun resolveUsbDevice(deviceId: String): UsbDevice? {
        val trimmed = deviceId.trim()
        if (trimmed.isEmpty()) return null

        val devices = usbManager().deviceList.values

        PRODUCT_ID_SUFFIX.matcher(trimmed).let { matcher ->
            if (matcher.find()) {
                val productId = matcher.group(1)?.toIntOrNull()
                if (productId != null) {
                    devices.firstOrNull { it.productId == productId }?.let { return it }
                }
            }
        }

        trimmed.toIntOrNull()?.let { productId ->
            devices.firstOrNull { it.productId == productId }?.let { return it }
        }

        devices.firstOrNull { device ->
            val name = device.productName ?: device.deviceName
            name.equals(trimmed, ignoreCase = true)
        }?.let { return it }

        return devices.firstOrNull { device ->
            val label = "${device.productName ?: device.deviceName} [${device.productId}]"
            label.equals(trimmed, ignoreCase = true)
        }
    }

    private fun connectUsb(call: MethodCall, result: Result) {
        val deviceId = call.argument<String>("deviceId")
        if (deviceId.isNullOrBlank()) {
            result.error("invalid_args", "deviceId is required", null)
            return
        }

        disconnectUsb()

        val device = resolveUsbDevice(deviceId)
        if (device == null) {
            result.error("not_found", "USB printer not found: $deviceId", null)
            return
        }

        val manager = usbManager()
        if (!manager.hasPermission(device)) {
            result.error(
                "no_permission",
                "USB permission not granted. Reconnect the printer or approve the USB prompt.",
                null,
            )
            return
        }

        val connection = manager.openDevice(device)
        if (connection == null) {
            result.error("open_failed", "Could not open USB device", null)
            return
        }

        var outEndpoint: UsbEndpoint? = null
        var claimedInterface: UsbInterface? = null

        outer@ for (i in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(i)
            if (!connection.claimInterface(usbInterface, true)) {
                continue
            }
            for (j in 0 until usbInterface.endpointCount) {
                val endpoint = usbInterface.getEndpoint(j)
                if (endpoint.direction == UsbConstants.USB_DIR_OUT) {
                    outEndpoint = endpoint
                    claimedInterface = usbInterface
                    break@outer
                }
            }
            connection.releaseInterface(usbInterface)
        }

        if (outEndpoint == null || claimedInterface == null) {
            connection.close()
            result.error("no_endpoint", "No USB bulk-out endpoint found on printer", null)
            return
        }

        usbConnection = connection
        usbOutEndpoint = outEndpoint
        connectedUsbDevice = device
        result.success(null)
    }

    private fun writeUsb(call: MethodCall, result: Result) {
        val data = call.argument<ByteArray>("data")
        if (data == null || data.isEmpty()) {
            result.error("invalid_args", "data bytes are required", null)
            return
        }

        val connection = usbConnection
        val endpoint = usbOutEndpoint
        if (connection == null || endpoint == null) {
            result.error("not_connected", "USB printer is not connected.", null)
            return
        }

        try {
            var offset = 0
            val chunkSize = endpoint.maxPacketSize.coerceAtLeast(512)
            while (offset < data.size) {
                val length = minOf(chunkSize, data.size - offset)
                val sent = connection.bulkTransfer(
                    endpoint,
                    data,
                    offset,
                    length,
                    5000,
                )
                if (sent < 0) {
                    result.error("usb_write_failed", "USB bulk transfer failed at offset $offset", null)
                    return
                }
                offset += sent
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("usb_write_failed", e.message, null)
        }
    }

    private fun disconnectUsb() {
        try {
            usbConnection?.close()
        } catch (_: Exception) {
        } finally {
            usbConnection = null
            usbOutEndpoint = null
            connectedUsbDevice = null
        }
    }

    private fun bluetoothAdapter(): BluetoothAdapter? {
        val manager = appContext.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter ?: BluetoothAdapter.getDefaultAdapter()
    }

    private fun normalizeAddress(address: String): String =
        address.trim().uppercase(Locale.US)

    private fun isBonded(adapter: BluetoothAdapter, address: String): Boolean {
        val normalized = normalizeAddress(address)
        val bonded = try {
            adapter.bondedDevices ?: emptySet()
        } catch (_: SecurityException) {
            emptySet()
        }
        return bonded.any { normalizeAddress(it.address) == normalized }
    }

    private fun listBluetoothDevices(result: Result) {
        val adapter = bluetoothAdapter()
        if (adapter == null) {
            result.success(emptyList<Map<String, String>>())
            return
        }

        if (!adapter.isEnabled) {
            result.error("bluetooth_disabled", "Enable Bluetooth on this device.", null)
            return
        }

        val bonded = try {
            adapter.bondedDevices ?: emptySet()
        } catch (security: SecurityException) {
            result.error("permission_denied", "Grant Bluetooth permissions to this app.", null)
            return
        }

        val devices = bonded.map { device ->
            mapOf(
                "name" to (device.name ?: "Bluetooth device"),
                "address" to device.address,
                "type" to "classic",
            )
        }
        result.success(devices)
    }

    private fun connectBluetooth(call: MethodCall, result: Result) {
        val address = call.argument<String>("address")
        if (address.isNullOrBlank()) {
            result.error("invalid_args", "address is required", null)
            return
        }

        val timeoutMs = call.argument<Int>("timeoutMs") ?: 15000

        val adapter = bluetoothAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.error("bluetooth_disabled", "Bluetooth is not available.", null)
            return
        }

        if (!isBonded(adapter, address)) {
            result.error(
                "not_paired",
                "Bluetooth printer is not paired. Open Android Settings > Bluetooth, pair the printer, then refresh the printer list.",
                null,
            )
            return
        }

        disconnectBluetooth()

        ioExecutor.execute {
            try {
                val device = adapter.getRemoteDevice(normalizeAddress(address))
                adapter.cancelDiscovery()
                val socket = openBluetoothSocket(device, timeoutMs)
                bluetoothSocket = socket
                result.success(null)
            } catch (security: SecurityException) {
                result.error("permission_denied", "Grant Bluetooth permissions to this app.", null)
            } catch (io: IOException) {
                result.error(
                    "bluetooth_connect_failed",
                    io.message ?: "Could not connect to Bluetooth printer.",
                    null,
                )
            } catch (e: Exception) {
                result.error(
                    "bluetooth_connect_failed",
                    e.message ?: "Could not connect to Bluetooth printer.",
                    null,
                )
            }
        }
    }

    @Throws(IOException::class)
    private fun openBluetoothSocket(device: BluetoothDevice, timeoutMs: Int): BluetoothSocket {
        var lastError: IOException? = null

        try {
            return connectWithTimeout(device.createRfcommSocketToServiceRecord(SPP_UUID), timeoutMs)
        } catch (error: IOException) {
            lastError = error
        }

        // Fallback channel used by many ESC/POS printers when SPP service lookup fails.
        try {
            val method = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
            val fallback = method.invoke(device, 1) as BluetoothSocket
            return connectWithTimeout(fallback, timeoutMs)
        } catch (error: Exception) {
            if (error is IOException) {
                lastError = error
            }
        }

        throw lastError ?: IOException("Could not open Bluetooth connection to printer.")
    }

    @Throws(IOException::class)
    private fun connectWithTimeout(socket: BluetoothSocket, timeoutMs: Int): BluetoothSocket {
        val worker = Thread {
            try {
                socket.connect()
            } catch (_: IOException) {
                try {
                    socket.close()
                } catch (_: IOException) {
                }
            }
        }
        worker.start()
        worker.join(timeoutMs.toLong())
        if (socket.isConnected) {
            return socket
        }
        try {
            socket.close()
        } catch (_: IOException) {
        }
        throw IOException("Bluetooth connection timed out. Check that the printer is on and paired.")
    }

    private fun writeBluetooth(call: MethodCall, result: Result) {
        val data = call.argument<ByteArray>("data")
        if (data == null || data.isEmpty()) {
            result.error("invalid_args", "data bytes are required", null)
            return
        }

        val socket = bluetoothSocket
        if (socket == null || !socket.isConnected) {
            result.error("not_connected", "Bluetooth socket is not connected.", null)
            return
        }

        ioExecutor.execute {
            try {
                socket.outputStream.write(data)
                socket.outputStream.flush()
                result.success(null)
            } catch (io: IOException) {
                result.error("bluetooth_write_failed", io.message, null)
            }
        }
    }

    private fun disconnectBluetooth() {
        try {
            bluetoothSocket?.close()
        } catch (_: IOException) {
        } finally {
            bluetoothSocket = null
        }
    }
}
