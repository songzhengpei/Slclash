import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/core.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';

import 'package:fl_clash/core/command_outcome.dart';
import 'package:fl_clash/core/interface.dart';

class CoreLib extends CoreHandlerInterface {
  static CoreLib? _instance;

  Completer<bool> _connectedCompleter = Completer();

  CoreLib._internal();

  @override
  Future<String> preload() async {
    if (_connectedCompleter.isCompleted) {
      return '';
    }
    final res = await service?.init().withTimeout(
      timeout: const Duration(seconds: 8),
      tag: 'service init',
      onTimeout: () => 'service init timeout',
    );
    if (res == null) {
      return CoreCommandOutcome.unconfirmed;
    }
    if (res.isNotEmpty) {
      return res;
    }
    _connectedCompleter.safeCompleter(true);
    final syncRes = await service?.syncState(
      globalState.container.read(sharedStateProvider),
    );
    return syncRes ?? CoreCommandOutcome.unconfirmed;
  }

  factory CoreLib() {
    _instance ??= CoreLib._internal();
    return _instance!;
  }

  @override
  FutureOr<bool> destroy() async {
    return true;
  }

  @override
  Future<bool> shutdown(_) async {
    if (!_connectedCompleter.isCompleted) {
      return false;
    }
    _connectedCompleter = Completer();
    final svc = service;
    if (svc == null) {
      return false;
    }
    return svc.shutdown();
  }

  @override
  Future<bool> startListener() async {
    final coreStarted = await super.startListener();
    if (!coreStarted) return false;
    final serviceStarted = await service?.start() ?? false;
    if (!serviceStarted) {
      await super.stopListener();
      await service?.stop();
      return false;
    }
    return true;
  }

  @override
  Future<bool> stopListener() async {
    await super.stopListener();
    await service?.stop();
    return true;
  }

  @override
  Future<T?> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
  }) async {
    final id = '${method.name}#${utils.id}';
    return CoreIpcTrace.run<T>(
      id: id,
      method: method.name,
      body: () async {
        final result = await service
            ?.invokeAction(Action(id: id, method: method, data: data))
            .withTimeout(timeout: timeout, onTimeout: () => null);
        if (result == null) {
          CoreIpcTrace.classify(id, 'transport_null_or_timeout');
          return null;
        }
        if (result.code == ResultType.error) {
          CoreIpcTrace.classify(id, 'core_error');
        } else {
          CoreIpcTrace.classify(id, 'success');
        }
        try {
          return await parasResult<T>(result);
        } catch (_) {
          CoreIpcTrace.classify(id, 'parse_error');
          rethrow;
        }
      },
    );
  }

  @override
  Completer get completer => _connectedCompleter;
}

CoreLib? get coreLib => system.isAndroid ? CoreLib() : null;
