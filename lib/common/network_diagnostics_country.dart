const countryKeywords = {
  'hk': 'HK',
  'hong kong': 'HK',
  '香港': 'HK',
  'tw': 'TW',
  'taiwan': 'TW',
  '台湾': 'TW',
  '臺灣': 'TW',
  'jp': 'JP',
  'japan': 'JP',
  '日本': 'JP',
  'sg': 'SG',
  'singapore': 'SG',
  '新加坡': 'SG',
  'us': 'US',
  'usa': 'US',
  'united states': 'US',
  'america': 'US',
  '美国': 'US',
  '美國': 'US',
  'kr': 'KR',
  'korea': 'KR',
  '韩国': 'KR',
  '韓國': 'KR',
  'uk': 'GB',
  'gb': 'GB',
  'united kingdom': 'GB',
  'britain': 'GB',
  '英国': 'GB',
  '英國': 'GB',
  'de': 'DE',
  'germany': 'DE',
  '德国': 'DE',
  '德國': 'DE',
  'fr': 'FR',
  'france': 'FR',
  '法国': 'FR',
  '法國': 'FR',
  'ca': 'CA',
  'canada': 'CA',
  '加拿大': 'CA',
  'au': 'AU',
  'australia': 'AU',
  '澳大利亚': 'AU',
  'nl': 'NL',
  'netherlands': 'NL',
  '荷兰': 'NL',
};

bool matchesCountryKeyword(String text, String keyword) {
  final isShortLatinKeyword = RegExp(r'^[a-z]{2,3}$').hasMatch(keyword);
  if (!isShortLatinKeyword) {
    return text.contains(keyword);
  }
  return RegExp(
    '(^|[^a-z])${RegExp.escape(keyword)}([^a-z]|\$)',
  ).hasMatch(text);
}

String? extractEmbeddedFlag(String text) {
  return RegExp(
    r'[\u{1F1E6}-\u{1F1FF}]{2}',
    unicode: true,
  ).firstMatch(text)?.group(0);
}

String? emojiToCountryCode(String emoji) {
  final runes = emoji.runes.toList();
  if (runes.length != 2) return null;
  final a = runes[0] - 0x1F1E6;
  final b = runes[1] - 0x1F1E6;
  if (a < 0 || a > 25 || b < 0 || b > 25) return null;
  return String.fromCharCodes([0x41 + a, 0x41 + b]);
}

String? extractCountryFromProxyName(String proxyName) {
  final flag = extractEmbeddedFlag(proxyName);
  if (flag != null) return emojiToCountryCode(flag);
  final lower = proxyName.toLowerCase();
  for (final entry in countryKeywords.entries) {
    if (matchesCountryKeyword(lower, entry.key)) return entry.value;
  }
  return null;
}

String? routeNameFromChains(List<String> chains) {
  for (final chain in chains.reversed) {
    final trimmed = chain.trim();
    if (trimmed.isEmpty) continue;
    return trimmed;
  }
  return null;
}

({String? routeName, String? country}) chainHeuristic(List<String> chains) {
  String? routeName;
  for (final chain in chains.reversed) {
    final trimmed = chain.trim();
    if (trimmed.isEmpty) continue;
    routeName ??= trimmed;
    if (trimmed.toUpperCase() == 'DIRECT') {
      return (routeName: trimmed, country: null);
    }
    final country = extractCountryFromProxyName(trimmed);
    if (country != null) {
      return (routeName: trimmed, country: country);
    }
  }
  return (routeName: routeName, country: null);
}
