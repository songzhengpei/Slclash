import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fl_clash/common/constant.dart';

const githubUpdateApiUrl =
    'https://api.github.com/repos/$repository/releases/latest';
const githubProxyPrefix = 'https://gh-proxy.com/';

String? githubProxyUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return null;
  if (uri.host != 'github.com' && uri.host != 'api.github.com') return null;
  return '$githubProxyPrefix$url';
}

List<String> githubReleaseDownloadUrls(String officialUrl) {
  final mirrorUrl = githubProxyUrl(officialUrl);
  return [?mirrorUrl, officialUrl];
}

String? githubAssetSha256(Object? digest) {
  final value = digest?.toString().trim().toLowerCase();
  if (value == null || !value.startsWith('sha256:')) return null;
  final hash = value.substring('sha256:'.length);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) return null;
  return hash;
}

Future<bool> fileMatchesSha256(String path, String expectedSha256) async {
  final actual = await sha256.bind(File(path).openRead()).first;
  return actual.toString().toLowerCase() == expectedSha256.toLowerCase();
}
