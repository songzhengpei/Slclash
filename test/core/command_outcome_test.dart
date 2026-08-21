import 'dart:async';

import 'package:fl_clash/core/command_outcome.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCoreHandler extends CoreHandlerInterface {
  FakeCoreHandler({this.invokeResult});

  String? invokeResult;
  Duration? lastTimeout;
  ActionMethod? lastMethod;

  final Completer<bool> _completer = Completer<bool>()..complete(true);

  @override
  Completer get completer => _completer;

  @override
  FutureOr<bool> destroy() async => true;

  @override
  Future<bool> shutdown(bool isUser) async => true;

  @override
  Future<String> preload() async => '';

  @override
  Future<T?> invoke<T>({
    required ActionMethod method,
    dynamic data,
    Duration? timeout,
  }) async {
    lastMethod = method;
    lastTimeout = timeout;
    return invokeResult as T?;
  }
}

void main() {
  const setupParams = SetupParams(selectedMap: {}, testUrl: 'http://x.com');
  const setupState = SetupState(
    profileId: null,
    profileLastUpdateDate: null,
    overwriteType: OverwriteType.standard,
    rules: [],
    proxyGroups: [],
    addedRules: [],
    script: null,
    overrideDns: false,
    dns: Dns(),
  );
  const updateParams = UpdateParams(
    tun: Tun(),
    mixedPort: 7890,
    allowLan: true,
    findProcessMode: FindProcessMode.off,
    mode: Mode.rule,
    logLevel: LogLevel.info,
    ipv6: false,
    tcpConcurrent: false,
    externalController: ExternalControllerStatus.close,
    unifiedDelay: false,
  );

  test('Core empty string remains confirmed success', () async {
    final core = FakeCoreHandler(invokeResult: '');
    expect(await core.validateConfig('/p'), '');
    expect(await core.setupConfig(setupParams), '');
    expect(
      await core.changeProxy(
        const ChangeProxyParams(groupName: 'G', proxyName: 'A'),
      ),
      '',
    );
    expect(
      await core.unfixProxy(const UnfixProxyParams(groupName: 'G')),
      '',
    );
    expect(await core.updateConfig(updateParams), '');
    expect(CoreCommandOutcome.isConfirmedSuccess(''), isTrue);
  });

  test('Core nonempty error is preserved', () async {
    const error = 'Must be a Selector';
    final core = FakeCoreHandler(invokeResult: error);
    expect(await core.validateConfig('/p'), error);
    expect(await core.setupConfig(setupParams), error);
    expect(
      await core.changeProxy(
        const ChangeProxyParams(groupName: 'G', proxyName: 'A'),
      ),
      error,
    );
    expect(
      await core.unfixProxy(const UnfixProxyParams(groupName: 'G')),
      error,
    );
    expect(await core.updateConfig(updateParams), error);
  });

  test('transport null becomes nonempty unconfirmed for command APIs', () async {
    final core = FakeCoreHandler(invokeResult: null);
    const expected = CoreCommandOutcome.unconfirmed;
    expect(await core.validateConfig('/p'), expected);
    expect(await core.setupConfig(setupParams), expected);
    expect(
      await core.changeProxy(
        const ChangeProxyParams(groupName: 'G', proxyName: 'A'),
      ),
      expected,
    );
    expect(
      await core.unfixProxy(const UnfixProxyParams(groupName: 'G')),
      expected,
    );
    expect(await core.updateConfig(updateParams), expected);
    expect(
      await core.updateGeoData(
        const UpdateGeoDataParams(geoType: 'mmdb', geoName: 'Country'),
      ),
      expected,
    );
    expect(
      await core.sideLoadExternalProvider(providerName: 'p', data: 'x'),
      expected,
    );
    expect(await core.updateExternalProvider('p'), expected);
    expect(await core.deleteFile('/tmp/x'), expected);
    expect(expected, isNotEmpty);
    expect(CoreCommandOutcome.isConfirmedSuccess(expected), isFalse);
  });

  test('read paths still fail-soft on null', () async {
    final core = FakeCoreHandler(invokeResult: null);
    expect(await core.getConnections(), '');
    expect(await core.getMemory(), '');
    expect(await core.getTrafficSnapshot(false), '');
    expect(await core.getExternalProviders(), '');
  });

  test('setupConfig transport null does not preload TUN', () async {
    CoreController.resetInstance();
    final core = FakeCoreHandler(invokeResult: null);
    final controller = CoreController.test(core);
    var preloads = 0;
    final message = await controller.setupConfig(
      params: setupParams,
      setupState: setupState,
      preloadInvoke: () {
        preloads += 1;
      },
    );
    expect(message, CoreCommandOutcome.unconfirmed);
    expect(preloads, 0);
    expect(CoreController.shouldPreloadVpnAfterSetup(message), isFalse);
    CoreController.resetInstance();
  });

  test('asyncTestDelay still uses the declared 6s timeout', () async {
    final core = FakeCoreHandler(invokeResult: '{"name":"A","value":1}');
    await core.asyncTestDelay('http://x', 'A');
    expect(core.lastTimeout, const Duration(seconds: 6));
    expect(core.lastMethod, ActionMethod.asyncTestDelay);
  });

  test('materializeProfileSnapshot still uses the declared 30s timeout', () async {
    final core = FakeCoreHandler(invokeResult: null);
    await core.materializeProfileSnapshot(
      profilePath: '/p',
      selectedMap: const {},
      defaultTestUrl: 'http://x',
    );
    expect(core.lastTimeout, const Duration(seconds: 30));
  });
}
