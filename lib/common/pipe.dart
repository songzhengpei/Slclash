import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:win32/win32.dart';

const _pipeBufferSize = 256 * 1024;

class _PipeCmd {
  final int type; // 0 = write, 1 = shutdown
  final Uint8List? data;

  const _PipeCmd(this.type, this.data);
}

void _pipeIsolate(List<Object> args) {
  final pipeName = args[0] as String;
  final dataPort = args[1] as SendPort;

  final namePtr = pipeName.toNativeUtf16();

  final handle = CreateNamedPipe(
    namePtr,
    PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED,
    PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
    1,
    _pipeBufferSize,
    _pipeBufferSize,
    0,
    nullptr,
  );

  calloc.free(namePtr);

  if (handle == INVALID_HANDLE_VALUE) {
    dataPort.send(
      'error:CreateNamedPipe failed, Win32 error=${GetLastError()}',
    );
    return;
  }

  final writeRx = ReceivePort();

  final readBuf = calloc<Uint8>(_pipeBufferSize);
  final bytesRead = calloc<Uint32>();
  final overlapped = calloc<OVERLAPPED>();
  final readEvent = CreateEvent(nullptr, 1, 0, nullptr);
  overlapped.ref.hEvent = readEvent;

  var running = true;
  var clientConnected = false;

  writeRx.listen((msg) {
    if (msg is _PipeCmd) {
      if (msg.type == 0) {
        if (clientConnected && msg.data != null) {
          final buf = calloc<Uint8>(msg.data!.length);
          final written = calloc<Uint32>();
          buf.asTypedList(msg.data!.length).setAll(0, msg.data!);
          WriteFile(handle, buf, msg.data!.length, written, nullptr);
          calloc.free(written);
          calloc.free(buf);
        }
      } else if (msg.type == 1) {
        running = false;
        if (clientConnected) {
          DisconnectNamedPipe(handle);
          clientConnected = false;
        }
        writeRx.close();
      }
    }
  });

  final connectEvent = CreateEvent(nullptr, 1, 0, nullptr);
  final connectOverlapped = calloc<OVERLAPPED>();
  connectOverlapped.ref.hEvent = connectEvent;

  while (running) {
    final cr = ConnectNamedPipe(handle, connectOverlapped);
    if (cr == 0) {
      final err = GetLastError();
      if (err == ERROR_IO_PENDING) {
        while (running) {
          final wr = WaitForSingleObject(connectEvent, 100);
          if (wr == WAIT_OBJECT_0) break;
        }
        if (!running) break;
      } else if (err != ERROR_PIPE_CONNECTED) {
        dataPort.send('error:ConnectNamedPipe failed, Win32 error=$err');
        break;
      }
    }
    if (!running) break;

    clientConnected = true;
    dataPort.send(writeRx.sendPort);

    var readPending = false;
    while (running && clientConnected) {
      if (!readPending) {
        bytesRead.value = 0;
        final readResult = ReadFile(
          handle,
          readBuf,
          _pipeBufferSize,
          bytesRead,
          overlapped,
        );
        if (readResult != 0) {
          if (bytesRead.value > 0) {
            dataPort.send(
              Uint8List.fromList(readBuf.asTypedList(bytesRead.value)),
            );
          } else {
            break;
          }
        } else {
          final err = GetLastError();
          if (err == ERROR_IO_PENDING) {
            readPending = true;
          } else if (bytesRead.value > 0) {
            dataPort.send(
              Uint8List.fromList(readBuf.asTypedList(bytesRead.value)),
            );
          } else {
            break;
          }
        }
      }

      if (readPending) {
        final wr = WaitForSingleObject(readEvent, 100);
        if (wr == WAIT_OBJECT_0) {
          final got = GetOverlappedResult(handle, overlapped, bytesRead, 0);
          if (got != 0 && bytesRead.value > 0) {
            dataPort.send(
              Uint8List.fromList(readBuf.asTypedList(bytesRead.value)),
            );
            readPending = false;
          } else {
            break;
          }
        } else if (wr != WAIT_TIMEOUT) {
          break;
        }
      }
    }

    if (running && clientConnected) {
      DisconnectNamedPipe(handle);
      clientConnected = false;
      dataPort.send('closed');
    }
  }

  CloseHandle(readEvent);
  CloseHandle(connectEvent);
  calloc.free(connectOverlapped);
  calloc.free(overlapped);
  calloc.free(bytesRead);
  calloc.free(readBuf);
  CloseHandle(handle);
}

class NamedPipeServer {
  final String pipeName;
  Isolate? _isolate;
  SendPort? _writePort;
  ReceivePort? _responsePort;
  StreamSubscription? _responseSub;

  final _dataController = StreamController<Uint8List>.broadcast();
  Completer<void> _connectionCompleter = Completer<void>();

  void Function()? onDisconnect;

  NamedPipeServer._(this.pipeName);

  Stream<Uint8List> get dataStream => _dataController.stream;
  Completer<void> get connectionCompleter => _connectionCompleter;

  static Future<NamedPipeServer> bind(String pipeName) async {
    final server = NamedPipeServer._(pipeName);
    server._responsePort = ReceivePort();

    server._responseSub = server._responsePort!.listen((message) {
      if (message is SendPort) {
        server._writePort = message;
        if (server._connectionCompleter.isCompleted) {
          server._connectionCompleter = Completer<void>();
        }
        server._connectionCompleter.complete();
      } else if (message is Uint8List) {
        server._dataController.add(message);
      } else if (message == 'closed') {
        server._connectionCompleter = Completer<void>();
        server.onDisconnect?.call();
      } else if (message is String && message.startsWith('error:')) {
        commonPrint.log('[NamedPipeServer] $message', logLevel: LogLevel.error);
      }
    });

    server._isolate = await Isolate.spawn(_pipeIsolate, [
      pipeName,
      server._responsePort!.sendPort,
    ]);

    return server;
  }

  void writeln(String message) {
    final wp = _writePort;
    if (wp == null) return;
    final str = '$message\n';
    wp.send(_PipeCmd(0, Uint8List.fromList(str.codeUnits)));
  }

  Future<void> close() async {
    final wp = _writePort;
    if (wp == null) return;
    _writePort = null;
    wp.send(const _PipeCmd(1, null));
    _responseSub?.cancel();
    _responsePort?.close();
    await Future.delayed(const Duration(milliseconds: 50));
    _isolate?.kill();
    _isolate = null;
  }
}
