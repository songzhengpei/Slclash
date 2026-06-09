import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/request.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('RealTunEnable provider', () {
    test('default is false', () {
      expect(container.read(realTunEnableProvider), false);
    });

    test('can update to true', () {
      container.read(realTunEnableProvider.notifier).update((_) => true);
      expect(container.read(realTunEnableProvider), true);
    });
  });

  group('Packages provider', () {
    test('default is empty list', () {
      expect(container.read(packagesProvider), isEmpty);
    });

    test('can update state', () {
      const pkg = Package(
        packageName: 'test.app',
        label: 'Test App',
        system: false,
        internet: true,
        lastUpdateTime: 0,
      );
      container.read(packagesProvider.notifier).update((_) => [pkg]);
      expect(container.read(packagesProvider).length, 1);
      expect(container.read(packagesProvider).first.packageName, 'test.app');
    });
  });

  group('SystemBrightness provider', () {
    test('default is dark', () {
      expect(container.read(systemBrightnessProvider), Brightness.dark);
    });

    test('can update to light', () {
      container
          .read(systemBrightnessProvider.notifier)
          .update((_) => Brightness.light);
      expect(container.read(systemBrightnessProvider), Brightness.light);
    });
  });

  group('LocalIp provider', () {
    test('default is null', () {
      expect(container.read(localIpProvider), null);
    });

    test('can set IP', () {
      container.read(localIpProvider.notifier).update((_) => '192.168.1.1');
      expect(container.read(localIpProvider), '192.168.1.1');
    });
  });

  group('RunTime provider', () {
    test('default is null', () {
      expect(container.read(runTimeProvider), null);
    });

    test('can set runtime', () {
      container.read(runTimeProvider.notifier).update((_) => 3600);
      expect(container.read(runTimeProvider), 3600);
    });
  });

  group('ViewSize provider', () {
    test('default is zero', () {
      expect(container.read(viewSizeProvider), Size.zero);
    });

    test('can update size', () {
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(800, 600));
      final value = container.read(viewSizeProvider);
      expect(value.width, 800);
      expect(value.height, 600);
    });
  });

  group('SideWidth provider', () {
    test('default is 0', () {
      expect(container.read(sideWidthProvider), 0.0);
    });

    test('can update side width', () {
      container.read(sideWidthProvider.notifier).update((_) => 300.0);
      expect(container.read(sideWidthProvider), 300.0);
    });
  });

  group('viewWidth provider (derived)', () {
    test('derives from viewSize width', () {
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(800, 600));
      expect(container.read(viewWidthProvider), 800);
    });
  });

  group('viewHeight provider (derived)', () {
    test('derives from viewSize height', () {
      container
          .read(viewSizeProvider.notifier)
          .update((_) => const Size(800, 600));
      expect(container.read(viewHeightProvider), 600);
    });
  });

  group('Init provider', () {
    test('default is false', () {
      expect(container.read(initProvider), false);
    });

    test('can update to true', () {
      container.read(initProvider.notifier).update((_) => true);
      expect(container.read(initProvider), true);
    });
  });

  group('CurrentPageLabel provider', () {
    test('default is dashboard', () {
      expect(container.read(currentPageLabelProvider), PageLabel.dashboard);
    });

    test('toPage changes page', () {
      container
          .read(currentPageLabelProvider.notifier)
          .toPage(PageLabel.proxies);
      expect(container.read(currentPageLabelProvider), PageLabel.proxies);
    });

    test('toProfiles changes page', () {
      container.read(currentPageLabelProvider.notifier).toProfiles();
      expect(container.read(currentPageLabelProvider), PageLabel.profiles);
    });
  });

  group('SortNum provider', () {
    test('default is 0', () {
      expect(container.read(sortNumProvider), 0);
    });

    test('can update', () {
      container.read(sortNumProvider.notifier).update((_) => 5);
      expect(container.read(sortNumProvider), 5);
    });
  });

  group('BackBlock provider', () {
    test('default is false', () {
      expect(container.read(backBlockProvider), false);
    });

    test('can update', () {
      container.read(backBlockProvider.notifier).update((_) => true);
      expect(container.read(backBlockProvider), true);
    });
  });

  group('Version provider', () {
    test('default is 0', () {
      expect(container.read(versionProvider), 0);
    });

    test('can set version', () {
      container.read(versionProvider.notifier).update((_) => 3);
      expect(container.read(versionProvider), 3);
    });
  });

  group('Groups provider', () {
    test('default is empty', () {
      expect(container.read(groupsProvider), isEmpty);
    });

    test('can set groups', () {
      final groups = [
        const Group(name: 'G1', type: GroupType.Selector, now: 'auto'),
      ];
      container.read(groupsProvider.notifier).update((_) => groups);
      expect(container.read(groupsProvider).length, 1);
      expect(container.read(groupsProvider).first.name, 'G1');
    });
  });

  group('TotalTraffic provider', () {
    test('default is empty Traffic', () {
      final t = container.read(totalTrafficProvider);
      expect(t.up, 0);
      expect(t.down, 0);
    });
  });

  group('CheckIpNum provider', () {
    test('default is 0', () {
      expect(container.read(checkIpNumProvider), 0);
    });

    test('increment works', () {
      container.read(checkIpNumProvider.notifier).update((_) => 3);
      expect(container.read(checkIpNumProvider), 3);
    });
  });

  group('CoreStatus provider', () {
    test('default is disconnected', () {
      expect(container.read(coreStatusProvider), CoreStatus.disconnected);
    });
  });

  group('NetworkDetection provider', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      originalAdapter = request.dio.httpClientAdapter;
    });

    tearDown(() {
      request.dio.httpClientAdapter = originalAdapter;
    });

    test(
      'ignores a canceled stale check after a newer check succeeds',
      () async {
        request.dio.httpClientAdapter = _DelayedCancelIpAdapter();
        final container = ProviderContainer(
          overrides: [
            initProvider.overrideWithBuild((_, _) => true),
            runTimeProvider.overrideWithBuild((_, _) => 1),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(networkDetectionProvider.notifier);
        notifier.startCheck();
        await Future.delayed(commonDuration + const Duration(milliseconds: 50));

        notifier.startCheck();
        await Future.delayed(
          commonDuration + const Duration(milliseconds: 120),
        );

        expect(container.read(networkDetectionProvider).ipInfo?.ip, '2.2.2.2');
        expect(container.read(networkDetectionProvider).isLoading, false);

        await Future.delayed(const Duration(milliseconds: 620));

        expect(container.read(networkDetectionProvider).ipInfo?.ip, '2.2.2.2');
        expect(container.read(networkDetectionProvider).isLoading, false);
      },
    );
  });
}

class _DelayedCancelIpAdapter implements HttpClientAdapter {
  static const _sourceCount = 7;

  int _requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    _requestCount++;
    final batch = ((_requestCount - 1) ~/ _sourceCount) + 1;
    if (batch == 1) {
      final completer = Completer<ResponseBody>();
      cancelFuture?.then((_) {
        Timer(const Duration(milliseconds: 500), () {
          if (completer.isCompleted) return;
          completer.completeError(
            DioException(
              requestOptions: options,
              type: DioExceptionType.cancel,
              error: 'cancelled',
            ),
          );
        });
      });
      return completer.future;
    }

    return Future.delayed(
      const Duration(milliseconds: 10),
      () => ResponseBody.fromString(
        '{"ip":"2.2.2.2","country_code":"US"}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}
