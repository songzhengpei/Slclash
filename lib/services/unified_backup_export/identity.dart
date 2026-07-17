import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'models.dart';

const unifiedBackupPublicBaseUrl =
    'https://mihomo-subscription-vault.nudymanu.workers.dev';
const _identityNamespace = 'slclash-unified-backup-v1';

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
