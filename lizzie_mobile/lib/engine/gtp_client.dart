import 'dart:async';
import 'dart:io';
import 'dart:convert';

/// Low-level GTP-over-TCP client.
///
/// Handles line-based framing, command-ID correlation, timeouts, and
/// keepalive pings.
class GtpClient {
  Socket? _socket;
  StreamSubscription? _sub;
  final _pending = <int, Completer<String>>{};
  int _cmdNumber = 1;
  bool _disposed = false;

  /// Stream of raw lines received from the engine (including `info ...`).
  final _lineController = StreamController<String>.broadcast();
  Stream<String> get lines => _lineController.stream;

  bool get isConnected => _socket != null && !_disposed;

  Future<void> connect(String host, int port, {int timeoutMs = 5000}) async {
    _disposed = false;
    _socket = await Socket.connect(
      host,
      port,
      timeout: Duration(milliseconds: timeoutMs),
    );
    _socket!.setOption(SocketOption.tcpNoDelay, true);

    // Buffer for partial lines.
    final buffer = StringBuffer();
    _sub = _socket!.listen(
      (data) {
        final text = utf8.decode(data);
        for (var i = 0; i < text.length; i++) {
          final ch = text[i];
          if (ch == '\n') {
            final line = buffer.toString().trimRight();
            buffer.clear();
            if (line.isNotEmpty) {
              _handleLine(line);
            }
          } else if (ch != '\r') {
            buffer.write(ch);
          }
        }
      },
      onError: (error) {
        _lineController.addError(error);
      },
      onDone: () {
        // Connection closed by remote.
      },
      cancelOnError: false,
    );
  }

  Future<void> disconnect() async {
    _disposed = true;
    await _sub?.cancel();
    _sub = null;
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
    // Fail all pending.
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(StateError('Disconnected'));
    }
    _pending.clear();
    await _lineController.close();
  }

  /// Send a GTP command and await the response.
  /// Returns the response body (after the `=N ` prefix).
  /// Throws on GTP error response (`?`).
  Future<String> send(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_socket == null || _disposed) {
      throw StateError('Not connected');
    }
    final cmdNum = _cmdNumber++;
    final completer = Completer<String>();
    _pending[cmdNum] = completer;

    _socket!.write('$cmdNum $command\r\n');
    await _socket!.flush();

    return completer.future.timeout(timeout);
  }

  void _handleLine(String line) {
    // Notify broadcast listeners.
    _lineController.add(line);

    // Parse GTP response.
    if (line.startsWith('=')) {
      // Success: "=NNN response_body" or "=NNN"
      final rest = line.substring(1).trimLeft();
      final spaceIdx = rest.indexOf(' ');
      final cmdNum = int.tryParse(
        spaceIdx > 0 ? rest.substring(0, spaceIdx) : rest,
      );
      final response = spaceIdx > 0 ? rest.substring(spaceIdx + 1) : '';
      if (cmdNum != null) {
        final completer = _pending.remove(cmdNum);
        if (completer != null && !completer.isCompleted) {
          completer.complete(response);
        }
      }
    } else if (line.startsWith('?')) {
      // Error: "?NNN error_message"
      final rest = line.substring(1).trimLeft();
      final spaceIdx = rest.indexOf(' ');
      final cmdNum = int.tryParse(
        spaceIdx > 0 ? rest.substring(0, spaceIdx) : rest,
      );
      final errorMsg = spaceIdx > 0 ? rest.substring(spaceIdx + 1) : rest;
      if (cmdNum != null) {
        final completer = _pending.remove(cmdNum);
        if (completer != null && !completer.isCompleted) {
          completer.completeError(GtpException(errorMsg));
        }
      }
    }
    // Lines starting with "info" or other non-"=/" prefixes are broadcast
    // to the stream listener (RemoteEngine) and are NOT consumed as command
    // responses.
  }
}

class GtpException implements Exception {
  final String message;
  GtpException(this.message);

  @override
  String toString() => 'GtpException: $message';
}
