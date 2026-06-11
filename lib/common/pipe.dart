import 'dart:async';
import 'dart:typed_data';

class NamedPipeServer {
  Stream<Uint8List> get dataStream => const Stream.empty();

  Completer<void> get connectionCompleter => Completer<void>()..complete();

  void Function()? onDisconnect;

  static Future<NamedPipeServer> bind(String pipeName) async {
    return NamedPipeServer();
  }

  void writeln(String message) {}

  Future<void> close() async {}
}
