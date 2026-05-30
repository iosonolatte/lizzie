package com.lizzie.engine

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import platform.Foundation.*
import kotlinx.cinterop.*

actual class GtpSocket {
    private var inputStream: NSInputStream? = null
    private var outputStream: NSOutputStream? = null
    private val readBuffer = StringBuilder()
    private var _isConnected = false

    actual val isConnected: Boolean get() = _isConnected

    actual suspend fun connect(host: String, port: Int, timeoutMs: Int) {
        withContext(Dispatchers.Default) {
            // Use NSStream to open TCP connection
            var readStream: Unmanaged<CFReadStream>? = null
            var writeStream: Unmanaged<CFWriteStream>? = null

            CFStreamCreatePairWithSocketToHost(
                null,
                host as CFStringRef,
                port.toUInt(),
                readStream?.retain(),
                writeStream?.retain()
            )

            inputStream = readStream?.takeRetainedValue() as? NSInputStream
            outputStream = writeStream?.takeRetainedValue() as? NSOutputStream

            inputStream?.open()
            outputStream?.open()

            _isConnected = true
        }
    }

    actual suspend fun send(data: ByteArray) {
        withContext(Dispatchers.Default) {
            data.usePinned { pinned ->
                outputStream?.write(pinned.addressOf(0), data.size.toULong())
            }
        }
    }

    actual suspend fun readLine(): String? = withContext(Dispatchers.Default) {
        val buffer = ByteArray(1)
        while (true) {
            val readLen = inputStream?.read(buffer.refTo(0), 1)
            if (readLen == null || readLen <= 0) return@withContext null
            val c = buffer[0].toInt().toChar()
            if (c == '\n') {
                val line = readBuffer.toString()
                readBuffer.clear()
                return@withContext line
            }
            if (c != '\r') readBuffer.append(c)
        }
    }

    actual fun close() {
        inputStream?.close()
        outputStream?.close()
        _isConnected = false
    }
}