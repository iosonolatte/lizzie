package com.lizzie.engine

import java.io.InputStream
import java.io.OutputStream
import java.net.Socket
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

actual class GtpSocket {
    private var socket: Socket? = null
    private var input: InputStream? = null
    private var output: OutputStream? = null
    private val readBuffer = StringBuilder()

    actual val isConnected: Boolean get() = socket?.isConnected == true && !socket!!.isClosed

    actual suspend fun connect(host: String, port: Int, timeoutMs: Int) {
        withContext(Dispatchers.IO) {
            val s = Socket(host, port)
            s.soTimeout = timeoutMs
            socket = s
            input = s.getInputStream()
            output = s.getOutputStream()
        }
    }

    actual suspend fun send(data: ByteArray) {
        withContext(Dispatchers.IO) {
            output?.write(data)
            output?.flush()
        }
    }

    actual suspend fun readLine(): String? {
        return withContext<String?>(Dispatchers.IO) {
            readBuffer.clear()
            while (true) {
                val byte = input?.read()
                if (byte == null || byte == -1) return@withContext null
                val c = byte.toChar()
                if (c == '\n') {
                    val line = readBuffer.toString()
                    readBuffer.clear()
                    return@withContext line
                }
                if (c != '\r') readBuffer.append(c)
            }
        }
    }

    actual fun close() {
        try { socket?.close() } catch (_: Exception) {}
        socket = null
        input = null
        output = null
    }
}