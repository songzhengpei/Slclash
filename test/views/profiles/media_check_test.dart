import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/l10n/l10n.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/views/profiles/media_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MediaCheckCache', () {
    test('health-only samples keep full unlock result and update HTTPS', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final fullResult = MediaCheckResult(
        name: 'JP01',
        profileId: 7,
        profileLabel: 'daily',
        chatGPT: const MediaCheckItem(status: 'clean', region: 'JP'),
        youTube: const MediaCheckItem(status: 'available', region: 'JP'),
        https: const MediaHTTPSResult(delay: 80, success: 3, total: 3),
        region: 'JP',
        score: 7400,
        checkedAt: now - 1000,
      );
      final healthResult = MediaCheckResult(
        name: 'JP01',
        profileId: 7,
        profileLabel: 'daily',
        chatGPT: const MediaCheckItem(status: 'skipped'),
        youTube: const MediaCheckItem(status: 'skipped'),
        https: const MediaHTTPSResult(delay: 92, success: 3, total: 3),
        region: '',
        score: 2400,
        checkedAt: now,
      );

      final cache = const MediaCheckCache(entries: {})
          .addResult(
            key: '7::JP01',
            profileId: 7,
            profileLabel: 'daily',
            proxyName: 'JP01',
            result: fullResult,
            mode: 'gpt',
          )
          .addResult(
            key: '7::JP01',
            profileId: 7,
            profileLabel: 'daily',
            proxyName: 'JP01',
            result: fullResult,
            mode: 'youtube',
          )
          .addHealthResult(
            key: '7::JP01',
            profileId: 7,
            profileLabel: 'daily',
            proxyName: 'JP01',
            result: healthResult,
          );

      final entry = cache.entries['7::JP01']!;
      expect(entry.samples, hasLength(1));
      expect(entry.lastResult!.chatGPT.chatGPTCompactLabel, '解锁(JP)');
      expect(entry.lastResult!.youTube.youtubeCompactLabel, '解锁(JP)');
      expect(entry.lastResult!.https.delay, 92);
      expect(entry.health.greenRate, 1);
      expect(entry.health.greenStreak, 1);
    });

    test('stable low latency needs enough green history', () {
      final now = DateTime.now().millisecondsSinceEpoch;

      MediaHealthSample sample(int offset, int delay, bool green) {
        return MediaHealthSample(
          checkedAt: now + offset,
          delay: delay,
          green: green,
          chatGPT: true,
        );
      }

      final tooFresh = MediaHealthStats.fromSamples([
        sample(1, 82, true),
        sample(2, 88, true),
      ]);
      expect(tooFresh.isStableLowLatency, false);

      final unstable = MediaHealthStats.fromSamples([
        sample(1, 82, true),
        sample(2, 88, false),
        sample(3, 91, true),
        sample(4, 94, true),
      ]);
      expect(unstable.isStableLowLatency, false);

      final stable = MediaHealthStats.fromSamples([
        sample(1, 82, true),
        sample(2, 88, true),
        sample(3, 91, true),
      ]);
      expect(stable.isStableLowLatency, true);

      final slow = MediaHealthStats.fromSamples([
        sample(1, 920, true),
        sample(2, 950, true),
        sample(3, 970, true),
      ]);
      expect(slow.isStableLowLatency, false);
    });
  });

  group('MediaCheckObserveSettings', () {
    test('normalizes unsupported intervals', () {
      final settings = MediaCheckObserveSettings.fromJson({
        'enabled': true,
        'interval-minutes': 17,
        'last-run-at': 123,
      });

      expect(settings.enabled, true);
      expect(settings.intervalMinutes, 60);
      expect(settings.intervalLabel, '1h');
      expect(settings.lastRunAt, 123);
    });
  });

  group('MediaCheckItem labels', () {
    test('collapses negative unlock states into timeout and blocked', () {
      expect(
        const MediaCheckItem(status: 'clean', region: 'JP').chatGPTCompactLabel,
        '解锁(JP)',
      );
      expect(const MediaCheckItem(status: 'failed').chatGPTCompactLabel, '超时');
      expect(const MediaCheckItem(status: 'timeout').chatGPTCompactLabel, '超时');
      expect(const MediaCheckItem(status: 'unknown').chatGPTCompactLabel, '超时');
      expect(
        const MediaCheckItem(
          status: 'unsupported',
          region: 'HK',
        ).chatGPTCompactLabel,
        '阻断',
      );
      expect(
        const MediaCheckItem(status: 'disallowed_isp').chatGPTCompactLabel,
        '阻断',
      );
      expect(const MediaCheckItem(status: 'blocked').chatGPTCompactLabel, '阻断');

      expect(
        const MediaCheckItem(
          status: 'unavailable',
          region: 'HK',
        ).youtubeCompactLabel,
        '送中',
      );
      expect(const MediaCheckItem(status: 'failed').youtubeCompactLabel, '超时');
      expect(const MediaCheckItem(status: 'timeout').youtubeCompactLabel, '超时');
      expect(const MediaCheckItem(status: 'unknown').youtubeCompactLabel, '超时');
    });
  });

  group('ProfileMediaCheckView', () {
    testWidgets('renders control card and fixed filter grid', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final profiles = [
        const Profile(
          id: 1,
          label: 'Daily',
          autoUpdateDuration: Duration(hours: 24),
        ),
        const Profile(
          id: 2,
          label: 'AI',
          autoUpdateDuration: Duration(hours: 24),
        ),
      ];

      Future<Map<String, dynamic>> loadConfig(int profileId) async {
        return {
          'proxies': [
            {
              'name': profileId == 1 ? '🇯🇵 JP01' : '🇸🇬 SG01',
              'type': 'Vless',
            },
            if (profileId == 1) {'name': '🇭🇰 HK01', 'type': 'Vless'},
          ],
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.delegate.supportedLocales,
          home: ProfileMediaCheckView(
            profiles: profiles,
            initialProfile: profiles.first,
            configLoader: loadConfig,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('节点体检'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('GPT'), findsWidgets);
      expect(find.text('YouTube'), findsWidgets);
      expect(find.text('健康'), findsWidgets);
      expect(find.text('检测结果会展示在这里'), findsOneWidget);
    });
  });
}
