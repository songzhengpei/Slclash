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
}
