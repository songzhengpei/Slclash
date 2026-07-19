import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'models.dart';

const unifiedBackupPublicBaseUrl =
    'https://mihomo-subscription-vault.nudymanu.workers.dev';
const unifiedBackupCustomBaseUrl = 'https://sub.misaeng.eu.org';
const unifiedBackupTrustedBaseUrls = <String>{
  unifiedBackupPublicBaseUrl,
  unifiedBackupCustomBaseUrl,
};
const _identityNamespace = 'slclash-unified-backup-v1';

bool isTrustedUnifiedBackupBaseUrl(Object? value) =>
    value is String && unifiedBackupTrustedBaseUrls.contains(value);

int deriveClashVergeProfileId(String uid) => int.parse(
  sha256
      .convert(utf8.encode('clash-verge-rev\n$uid'))
      .toString()
      .substring(0, 15),
  radix: 16,
);

UnifiedIdentity deriveUnifiedIdentity(int androidId) {
  final digest = sha256
      .convert(
        utf8.encode(
          '$_identityNamespace\n$unifiedBackupPublicBaseUrl\n$androidId',
        ),
      )
      .toString();
  return UnifiedIdentity(
    slug: 'android-${digest.substring(0, 20)}',
    subscriptionId: 'slclash-${digest.substring(0, 32)}',
    profileUid: 'R${digest.substring(0, 8)}',
  );
}
