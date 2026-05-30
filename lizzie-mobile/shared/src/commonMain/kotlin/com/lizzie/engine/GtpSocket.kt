package com.lizzie.engine

/**
 * Platform-specific TCP connection for GTP communication.
 *
 * Android: Uses java.net.Socket
 * iOS: Uses NSInputStream/NSOutputStream
 */
expect class GtpSocket {
    /** Connect to host:port. Throws on failure. */
    suspend fun connect(host: String, port: Int, timeoutMs: Int = 5000)

    /** Send a GTP command. */
    suspend fun send(data: ByteArray)

    /** Read a line of output (blocking until \n). */
    suspend fun readLine(): String?

    /** Close the connection. */
    fun close()

    /** True if the socket is connected and not closed. */
    val isConnected: Boolean
}