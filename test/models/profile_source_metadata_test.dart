import 'dart:typed_data';

import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final latest = Profile(
    id: 7,
    label: 'newest user label',
    url: 'https://new.example/profile',
    lastUpdateDate: DateTime(2025),
    autoUpdateDuration: const Duration(hours: 9),
    subscriptionInfo: const SubscriptionInfo(upload: 1),
    autoUpdate: false,
    selectedMap: const {'group': 'selected'},
    computedSelectedMap: const {'group': 'computed'},
    unfoldSet: const {'group'},
    overwriteType: OverwriteType.standard,
    scriptId: 42,
    order: 3,
    currentGroupName: 'group',
  );
  final response = ProfileSourceResponse(
    bytes: Uint8List.fromList([1]),
    subscriptionInfo: const SubscriptionInfo(
      upload: 10,
      download: 20,
      total: 30,
      expire: 40,
    ),
    fallbackLabel: 'server label',
  );

  test('remote metadata merge preserves latest user-owned fields', () {
    final updatedAt = DateTime(2026);
    final merged = mergeRemoteProfileResponse(
      latest,
      response,
      updatedAt: updatedAt,
    );

    expect(merged.label, latest.label);
    expect(merged.url, latest.url);
    expect(merged.autoUpdate, latest.autoUpdate);
    expect(merged.autoUpdateDuration, latest.autoUpdateDuration);
    expect(merged.overwriteType, latest.overwriteType);
    expect(merged.scriptId, latest.scriptId);
    expect(merged.selectedMap, latest.selectedMap);
    expect(merged.computedSelectedMap, latest.computedSelectedMap);
    expect(merged.currentGroupName, latest.currentGroupName);
    expect(merged.unfoldSet, latest.unfoldSet);
    expect(merged.order, latest.order);
    expect(merged.subscriptionInfo, response.subscriptionInfo);
    expect(merged.lastUpdateDate, updatedAt);
  });

  test('server fallback label is used only when latest label is empty', () {
    final merged = mergeRemoteProfileResponse(
      latest.copyWith(label: ''),
      response,
      updatedAt: DateTime(2026),
    );
    expect(merged.label, 'server label');
  });

  test('response identity is rejected after URL edit or deletion', () {
    expect(
      isProfileSourceIdentityCurrent(
        latest,
        profileId: latest.id,
        sourceUrl: 'https://old.example/profile',
      ),
      isFalse,
    );
    expect(
      isProfileSourceIdentityCurrent(
        null,
        profileId: latest.id,
        sourceUrl: latest.url,
      ),
      isFalse,
    );
    expect(
      isProfileSourceIdentityCurrent(
        latest,
        profileId: latest.id,
        sourceUrl: latest.url,
      ),
      isTrue,
    );
  });
}
