import 'package:fl_clash/common/iterable.dart';
import 'package:fl_clash/common/proxy_page_entry.dart';
import 'package:fl_clash/common/proxy_trace.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(ProxyTrace.resetForTest);

  test('eager list count is headers plus expanded proxies', () {
    expect(
      ProxyTrace.eagerWidgetCount(headers: 4, expandedProxies: 300),
      304,
    );
    expect(
      ProxyTrace.eagerWidgetCount(headers: 2, expandedProxies: 500),
      502,
    );
  });

  test('eager materialization scales 20/100/300/500', () {
    for (final n in [20, 100, 300, 500]) {
      expect(
        ProxyTrace.eagerWidgetCount(headers: 1, expandedProxies: n),
        n + 1,
      );
    }
  });

  test('map-toList starts every delay future before batch await', () async {
    Future<int> peakFor(int n) async {
      var started = 0;
      var inflight = 0;
      var peak = 0;
      Future<void> job() async {
        started += 1;
        inflight += 1;
        if (inflight > peak) {
          peak = inflight;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inflight -= 1;
      }

      final delayProxies = List<Future<void>>.generate(n, (_) => job());
      expect(started, n);
      final batches = delayProxies.batch(100);
      for (final batch in batches) {
        await Future.wait(batch);
      }
      return peak;
    }

    expect(await peakFor(20), 20);
    expect(await peakFor(100), 100);
    expect(await peakFor(300), 300);
    expect(await peakFor(500), 500);
  });

  test('ACK gen is the request gen not the latest intent', () {
    final first = ProxyTrace.noteSelectIntent(group: 'g', proxy: 'A');
    final second = ProxyTrace.noteSelectIntent(group: 'g', proxy: 'B');
    expect(first, 1);
    expect(second, 2);
    expect(ProxyTrace.selectionGen, 2);
    expect(ProxyTrace.supersededCount, 1);
    ProxyTrace.noteSelectDispatch(gen: first, group: 'g', proxy: 'A');
    ProxyTrace.noteSelectCoreAck(gen: first, group: 'g', result: '');
    expect(ProxyTrace.lastAckGen, first);
    expect(ProxyTrace.lastAckGen, isNot(second));
    expect(ProxyTrace.ackCount, 1);
  });

  test('event-scoped dump resets hotspot counters', () {
    ProxyTrace.beginSession();
    ProxyTrace.noteHotspotBuild('list_header');
    ProxyTrace.noteHotspotBuild('list_header');
    ProxyTrace.noteHotspotBuild('proxy_card');
    expect(ProxyTrace.dumpEventScope(event: 'E1')['list_header'], 2);
    ProxyTrace.resetEventScope(event: 'E2');
    expect(ProxyTrace.dumpEventScope(event: 'E2')['list_header'], 0);
    expect(ProxyTrace.dumpEventScope(event: 'E2')['proxy_card'], 0);
  });

  test('P-matrix entry plan matches ProxiesView predicates', () {
    expect(
      const ProxyPageEntryPlan(
        ownerProfileId: 1,
        currentProfileId: 1,
        groupsIsEmpty: false,
        expired: false,
        snapshotHydrated: true,
      ).ensureReady,
      isFalse,
    );
    expect(
      const ProxyPageEntryPlan(
        ownerProfileId: 1,
        currentProfileId: 1,
        groupsIsEmpty: false,
        expired: true,
        snapshotHydrated: true,
      ).scenarioId,
      'P2_stale_snapshot',
    );
    expect(
      const ProxyPageEntryPlan(
        ownerProfileId: 1,
        currentProfileId: 1,
        groupsIsEmpty: true,
        expired: true,
        snapshotHydrated: false,
      ).scenarioId,
      'P3_no_snapshot',
    );
    expect(
      const ProxyPageEntryPlan(
        ownerProfileId: 1,
        currentProfileId: 2,
        groupsIsEmpty: false,
        expired: false,
        snapshotHydrated: true,
      ).forceApply,
      isTrue,
    );
    expect(
      const ProxyPageEntryPlan(
        ownerProfileId: 1,
        currentProfileId: 2,
        groupsIsEmpty: false,
        expired: false,
        snapshotHydrated: true,
      ).scenarioId,
      'P8_owner_mismatch',
    );
  });

  testWidgets(
    '_buildItems-style eager widgets vs ListView.builder viewport builds',
    (tester) async {
      var builds = 0;
      final items = List<Widget>.generate(500, (index) {
        return _CountBuild(
          onBuild: () => builds += 1,
          child: SizedBox(height: 48, child: Text('n$index')),
        );
      });
      expect(items.length, 500);
      expect(builds, 0);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            height: 640,
            child: ListView.builder(
              itemExtent: 48,
              itemCount: items.length,
              itemBuilder: (_, index) => items[index],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(builds, greaterThan(0));
      expect(builds, lessThan(40));
    },
  );

  test('synthetic selector fixture stays Group/all shaped', () {
    final group = syntheticSelectorGroup(300);
    expect(group.type, GroupType.Selector);
    expect(group.all.length, 300);
    expect(group.all.first.name, 'n0001');
  });
}

class _CountBuild extends StatelessWidget {
  const _CountBuild({required this.onBuild, required this.child});

  final VoidCallback onBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}

Group syntheticSelectorGroup(int n) {
  return Group(
    name: 'PERF',
    type: GroupType.Selector,
    all: [
      for (var i = 1; i <= n; i++)
        Proxy(name: 'n${i.toString().padLeft(4, '0')}', type: 'direct'),
    ],
  );
}
