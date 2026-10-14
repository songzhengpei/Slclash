import 'package:fl_clash/core/command_outcome.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.follow.clash/service');
  final service = Service();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('init transport null remains unconfirmed', () async {
    final result = await service.init();

    expect(result, isNull);
    expect(
      CoreCommandOutcome.fromInvoke(result),
      CoreCommandOutcome.unconfirmed,
    );
  });

  test('syncState transport null remains unconfirmed', () async {
    const state = SharedState(
      stopTip: '',
      startTip: '',
      currentProfileName: '',
      stopText: '',
      onlyStatisticsProxy: false,
    );

    final result = await service.syncState(state);

    expect(result, isNull);
    expect(
      CoreCommandOutcome.fromInvoke(result),
      CoreCommandOutcome.unconfirmed,
    );
  });

  test('shutdown transport null fails closed', () async {
    expect(await service.shutdown(), isFalse);
  });

  test('smart pause sends independent application and network lists', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          captured = call;
          return true;
        });
    expect(
      await service.updateSmartPauseConfig(
        enabled: true,
        trustedNetworks: const [],
        triggerApplications: const ['app.a', 'app.b'],
        closeConnections: true,
      ),
      isTrue,
    );
    expect(captured?.method, 'updateSmartPauseConfig');
    expect(captured?.arguments, {
      'enabled': true,
      'trustedNetworks': <String>[],
      'triggerApplications': ['app.a', 'app.b'],
      'closeConnections': true,
    });
  });

  test('missing usage permission response is not treated as granted', () async {
    expect(await service.hasUsageAccess(), isFalse);
    expect(await service.openUsageAccessSettings(), isFalse);
  });
}
