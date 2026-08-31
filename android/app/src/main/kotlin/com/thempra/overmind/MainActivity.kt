package com.thempra.overmind

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class MainActivity : FlutterActivity() {

    companion object {
        val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
        const val METHOD_CHANNEL = "overmind/spp"
        const val EVENT_CHANNEL = "overmind/spp/bytes"
    }

    private var adapter: BluetoothAdapter? = null
    private var eventSink: EventChannel.EventSink? = null
    private val sockets = ConcurrentHashMap<String, SocketHolder>()

    private class SocketHolder(val socket: BluetoothSocket) {
        @Volatile var running: Boolean = true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        adapter =
            (getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getDevices" -> handleGetDevices(result)
                        "connect" ->
                            handleConnect(call.argument<String>("address")!!, result)
                        "disconnect" ->
                            handleDisconnect(call.argument<String>("address")!!, result)
                        else -> result.notImplemented()
                    }
                } catch (e: SecurityException) {
                    result.error("security", e.message, null)
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?,
                ) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    /** Vinculados Classic/DUAL con nombre: los candidados a SPP. */
    private fun handleGetDevices(result: MethodChannel.Result) {
        val a = adapter
        if (a == null) {
            result.error("no_adapter", "Bluetooth adapter unavailable", null)
            return
        }
        val out = mutableListOf<Map<String, String>>()
        for (d in a.bondedDevices) {
            val type = d.type
            if (type != BluetoothDevice.DEVICE_TYPE_CLASSIC &&
                type != BluetoothDevice.DEVICE_TYPE_DUAL
            ) {
                continue
            }
            val name = d.name ?: continue
            if (name.isBlank()) continue
            out.add(mapOf("address" to d.address, "name" to name))
        }
        result.success(out)
    }

    /** RFCOMM/SPP en segundo plano: socket.connect() es bloqueante. */
    private fun handleConnect(address: String, result: MethodChannel.Result) {
        val a = adapter
        if (a == null) {
            result.error("no_adapter", "Bluetooth adapter unavailable", null)
            return
        }
        if (sockets.containsKey(address)) {
            result.success(true)
            return
        }
        val device = a.getRemoteDevice(address)
        Thread {
            try {
                a.cancelDiscovery()
                val socket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                socket.connect()
                val holder = SocketHolder(socket)
                sockets[address] = holder
                runOnUiThread { result.success(true) }
                readLoop(address, holder)
            } catch (e: IOException) {
                sockets.remove(address)
                runOnUiThread { result.error("connect_failed", e.message, null) }
            } catch (e: SecurityException) {
                runOnUiThread { result.error("security", e.message, null) }
            }
        }.start()
    }

    private fun handleDisconnect(address: String, result: MethodChannel.Result) {
        val holder = sockets.remove(address)
        if (holder == null) {
            result.success(false)
            return
        }
        holder.running = false
        try {
            holder.socket.close()
        } catch (_: IOException) {
        }
        result.success(true)
    }

    /** Hilo lector: publica los chunks en el EventChannel y notifica el cierre. */
    private fun readLoop(address: String, holder: SocketHolder) {
        val buffer = ByteArray(512)
        try {
            val input = holder.socket.inputStream
            while (holder.running) {
                val n = input.read(buffer)
                if (n == -1) break
                if (n > 0) {
                    val chunk = buffer.copyOf(n)
                    runOnUiThread {
                        eventSink?.success(
                            mapOf("address" to address, "bytes" to chunk)
                        )
                    }
                }
            }
        } catch (_: IOException) {
            // Socket cerrado (disconnect) o caído: se notifica abajo.
        } finally {
            sockets.remove(address)
            runOnUiThread {
                eventSink?.success(mapOf("address" to address, "closed" to true))
            }
        }
    }
}
