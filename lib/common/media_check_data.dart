// Shared media-check data classes.
// Extracted from views/profiles/media_check.dart so that both the page-level
// UI and the app-level HealthObservationScheduler can read/write the same
// cache without circular imports.

import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_clash/common/preferences.dart';
import 'package:flutter/foundation.dart' show immutable, kDebugMode;

// ── Constants ──────────────────────────────────────────────────────────────

const mediaCheckCacheKey = 'media-check-cache-v2';
const mediaCheckObserveSettingsKey = 'media-check-observe-settings-v1';
const healthyMinSamples = 3;
const healthyMinGreenStreak = 3;
const healthyMinGreenRate = 0.85;
const healthyMaxMedianDelay = 800;
const cacheTTLSuccess = Duration(hours: 48);
const cacheTTLUnknown = Duration(hours: 24);
const cacheTTLError = Duration(hours: 6);
const cacheTTLHealth = Duration(days: 7);
const maxCacheEntries = 500;
const observeCooldownDuration = Duration(hours: 24);
const observeSlowDelayThreshold = 1500;
const observeConsecutiveBadLimit = 3;
const observeRecentWindow = 5;
const observeRecentBadLimit = 4;

// ── Helpers ────────────────────────────────────────────────────────────────

String firstNonEmptyStr(String first, String second) {
  return first.isNotEmpty ? first : second;
}

bool _isBadOrSlowHealthSample(MediaHealthSample sample) {
  return !sample.green ||
      sample.delay <= 0 ||
      sample.delay > observeSlowDelayThreshold;
}

// ── MediaCheckObserveSettings ──────────────────────────────────────────────

class MediaCheckObserveSettings {
  const MediaCheckObserveSettings({
    this.enabled = false,
    this.intervalMinutes = 60,
    this.lastRunAt = 0,
  });

  factory MediaCheckObserveSettings.fromJson(Map<String, dynamic> json) {
    final interval = json['interval-minutes'] as int? ?? 60;
    return MediaCheckObserveSettings(
      enabled: json['enabled'] as bool? ?? false,
      intervalMinutes: intervalOptions.contains(interval) ? interval : 60,
      lastRunAt: json['last-run-at'] as int? ?? 0,
    );
  }

  static List<int> get intervalOptions =>
      kDebugMode ? const [2, 20, 40, 60, 120] : const [20, 40, 60, 120];

  final bool enabled;
  final int intervalMinutes;
  final int lastRunAt;

  bool get isDue {
    if (lastRunAt <= 0) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastRunAt;
    return elapsed >= Duration(minutes: intervalMinutes).inMilliseconds;
  }

  String get intervalLabel {
    if (intervalMinutes < 60) return '${intervalMinutes}m';
    final hours = intervalMinutes ~/ 60;
    return '${hours}h';
  }

  MediaCheckObserveSettings copyWith({
    bool? enabled,
    int? intervalMinutes,
    int? lastRunAt,
  }) {
    return MediaCheckObserveSettings(
      enabled: enabled ?? this.enabled,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      lastRunAt: lastRunAt ?? this.lastRunAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'interval-minutes': intervalMinutes,
      'last-run-at': lastRunAt,
    };
  }
}

// ── MediaCheckCacheStore ───────────────────────────────────────────────────

class MediaCheckCacheStore {
  Future<MediaCheckCache> load() async {
    final raw = await preferences.getString(mediaCheckCacheKey);
    if (raw == null || raw.isEmpty) return const MediaCheckCache(entries: {});
    try {
      return MediaCheckCache.fromJson(
        json.decode(raw) as Map<String, dynamic>,
      ).purgeExpired();
    } catch (_) {
      return const MediaCheckCache(entries: {});
    }
  }

  Future<void> save(MediaCheckCache cache) async {
    await preferences.setString(mediaCheckCacheKey, json.encode(cache));
  }

  Future<MediaCheckObserveSettings> loadObserveSettings() async {
    final raw = await preferences.getString(mediaCheckObserveSettingsKey);
    if (raw == null || raw.isEmpty) {
      return const MediaCheckObserveSettings();
    }
    try {
      return MediaCheckObserveSettings.fromJson(
        json.decode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const MediaCheckObserveSettings();
    }
  }

  Future<void> saveObserveSettings(MediaCheckObserveSettings settings) async {
    await preferences.setString(
      mediaCheckObserveSettingsKey,
      json.encode(settings),
    );
  }
}

// ── MediaCheckCache ────────────────────────────────────────────────────────

class MediaCheckCache {
  const MediaCheckCache({required this.entries});

  factory MediaCheckCache.fromJson(Map<String, dynamic> json) {
    final entries = <String, MediaCheckCacheEntry>{};
    final rawEntries = Map<String, dynamic>.from(
      json['entries'] as Map? ?? const {},
    );
    for (final entry in rawEntries.entries) {
      entries[entry.key] = MediaCheckCacheEntry.fromJson(
        Map<String, dynamic>.from(entry.value as Map? ?? const {}),
      );
    }
    return MediaCheckCache(entries: entries);
  }

  final Map<String, MediaCheckCacheEntry> entries;

  MediaCheckCache addResult({
    required String key,
    required int profileId,
    required String profileLabel,
    required String proxyName,
    required MediaCheckResult result,
    required String mode,
  }) {
    final nextEntries = Map<String, MediaCheckCacheEntry>.from(entries);
    final previous = nextEntries[key];
    nextEntries[key] =
        (previous ??
                MediaCheckCacheEntry(
                  key: key,
                  profileId: profileId,
                  profileLabel: profileLabel,
                  proxyName: proxyName,
                  samples: const [],
                ))
            .addModeResult(result, mode);
    return MediaCheckCache(entries: nextEntries)._enforceCapacity();
  }

  MediaCheckCache addHealthResult({
    required String key,
    required int profileId,
    required String profileLabel,
    required String proxyName,
    required MediaCheckResult result,
  }) {
    final nextEntries = Map<String, MediaCheckCacheEntry>.from(entries);
    final previous = nextEntries[key];
    nextEntries[key] =
        (previous ??
                MediaCheckCacheEntry(
                  key: key,
                  profileId: profileId,
                  profileLabel: profileLabel,
                  proxyName: proxyName,
                  samples: const [],
                ))
            .addHealthResult(result);
    return MediaCheckCache(entries: nextEntries)._enforceCapacity();
  }

  MediaCheckCache clearModeForKeys({
    required Set<String> keys,
    required String mode,
  }) {
    final nextEntries = Map<String, MediaCheckCacheEntry>.from(entries);
    for (final key in keys) {
      final entry = nextEntries[key];
      if (entry == null) continue;
      final nextEntry = entry.clearMode(mode);
      if (nextEntry == null) {
        nextEntries.remove(key);
      } else {
        nextEntries[key] = nextEntry;
      }
    }
    return MediaCheckCache(entries: nextEntries);
  }

  /// Remove entries where every mode is expired and no health samples remain.
  MediaCheckCache purgeExpired() {
    final nextEntries = Map<String, MediaCheckCacheEntry>.from(entries);
    final keysToRemove = <String>[];
    for (final entry in nextEntries.entries) {
      final e = entry.value;
      final allExpired = e.modeTimes.keys.every(
        (mode) => e.isModeExpired(mode),
      );
      if (allExpired && e.samples.isEmpty) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      nextEntries.remove(key);
    }
    return MediaCheckCache(entries: nextEntries);
  }

  /// Evict oldest entries when exceeding [maxCacheEntries].
  MediaCheckCache _enforceCapacity() {
    if (entries.length <= maxCacheEntries) return this;
    final sorted = entries.entries.toList()
      ..sort((a, b) {
        int maxTime(Map<String, int> m) =>
            m.values.fold(0, (prev, v) => v > prev ? v : prev);
        return maxTime(a.value.modeTimes).compareTo(maxTime(b.value.modeTimes));
      });
    final nextEntries = Map<String, MediaCheckCacheEntry>.from(entries);
    while (sorted.length > maxCacheEntries) {
      nextEntries.remove(sorted.removeAt(0).key);
    }
    return MediaCheckCache(entries: nextEntries);
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 2,
      'entries': entries.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

// ── MediaCheckCacheEntry ───────────────────────────────────────────────────

class MediaCheckCacheEntry {
  const MediaCheckCacheEntry({
    required this.key,
    required this.profileId,
    required this.profileLabel,
    required this.proxyName,
    required this.samples,
    this.modeTimes = const {},
    this.lastResult,
    this.observeCooldownUntil = 0,
    this.observeBadStreak = 0,
    this.observeSlowStreak = 0,
    this.observeLastReason = '',
  });

  factory MediaCheckCacheEntry.fromJson(Map<String, dynamic> json) {
    return MediaCheckCacheEntry(
      key: json['key'] as String? ?? '',
      profileId: json['profile-id'] as int? ?? 0,
      profileLabel: json['profile-label'] as String? ?? '',
      proxyName: json['proxy-name'] as String? ?? '',
      lastResult: json['last-result'] == null
          ? null
          : MediaCheckResult.fromJson(
              Map<String, dynamic>.from(json['last-result'] as Map),
            ),
      samples: (json['samples'] as List? ?? const [])
          .map(
            (item) => MediaHealthSample.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      modeTimes: Map<String, int>.from(
        (json['mode-times'] as Map? ?? const {}).map(
          (key, value) => MapEntry('$key', (value as num?)?.toInt() ?? 0),
        ),
      ),
      observeCooldownUntil:
          (json['observe-cooldown-until'] as num?)?.toInt() ?? 0,
      observeBadStreak: (json['observe-bad-streak'] as num?)?.toInt() ?? 0,
      observeSlowStreak: (json['observe-slow-streak'] as num?)?.toInt() ?? 0,
      observeLastReason: json['observe-last-reason'] as String? ?? '',
    );
  }

  final String key;
  final int profileId;
  final String profileLabel;
  final String proxyName;
  final MediaCheckResult? lastResult;
  final List<MediaHealthSample> samples;
  final Map<String, int> modeTimes;
  final int observeCooldownUntil;
  final int observeBadStreak;
  final int observeSlowStreak;
  final String observeLastReason;

  MediaCheckCacheEntry addModeResult(MediaCheckResult result, String mode) {
    final merged = switch (mode) {
      'gpt' => (lastResult ?? result).copyWith(
        chatGPT: result.chatGPT,
        region: firstNonEmptyStr(
          result.chatGPT.region,
          lastResult?.region ?? '',
        ),
        checkedAt: result.checkedAt,
      ),
      'youtube' => (lastResult ?? result).copyWith(
        youTube: result.youTube,
        region: firstNonEmptyStr(
          result.youTube.region,
          lastResult?.region ?? '',
        ),
        checkedAt: result.checkedAt,
      ),
      _ => result,
    };
    return copyWith(
      lastResult: merged,
      modeTimes: {...modeTimes, mode: result.checkedAt},
    );
  }

  MediaCheckCacheEntry addHealthResult(MediaCheckResult result) {
    final sample = MediaHealthSample(
      checkedAt: result.checkedAt,
      delay: result.https.delay,
      green: result.https.isGreen,
      chatGPT: lastResult?.chatGPT.isChatGPTAvailable ?? false,
    );
    final nextLastResult = lastResult == null
        ? result
        : lastResult!.copyWith(
            https: result.https,
            checkedAt: result.checkedAt,
          );
    return _addSample(
      sample: sample,
      lastResult: nextLastResult,
      mode: 'health',
    );
  }

  MediaCheckCacheEntry _addSample({
    required MediaHealthSample sample,
    required MediaCheckResult lastResult,
    required String mode,
  }) {
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 7))
        .millisecondsSinceEpoch;
    final nextSamples = [
      ...samples.where((sample) => sample.checkedAt >= cutoff),
      sample,
    ];
    final trimmed = nextSamples.length > 168
        ? nextSamples.sublist(nextSamples.length - 168)
        : nextSamples;
    final isFailure = !sample.green || sample.delay <= 0;
    final isSlow = sample.green && sample.delay > observeSlowDelayThreshold;
    final isHealthy =
        sample.green &&
        sample.delay > 0 &&
        sample.delay <= observeSlowDelayThreshold;
    var nextBadStreak = observeBadStreak;
    var nextSlowStreak = observeSlowStreak;
    var nextCooldownUntil = observeCooldownUntil;
    var nextReason = observeLastReason;

    if (isFailure) {
      nextBadStreak++;
      nextSlowStreak = 0;
      nextReason = 'timeout';
    } else if (isSlow) {
      nextSlowStreak++;
      nextBadStreak = 0;
      nextReason = 'highDelay';
    } else if (isHealthy) {
      nextBadStreak = 0;
      nextSlowStreak = 0;
      nextCooldownUntil = 0;
      nextReason = '';
    }

    final recent = trimmed.length > observeRecentWindow
        ? trimmed.sublist(trimmed.length - observeRecentWindow)
        : trimmed;
    final recentBadOrSlow = recent.where(_isBadOrSlowHealthSample).length;
    final shouldCooldown =
        nextBadStreak >= observeConsecutiveBadLimit ||
        nextSlowStreak >= observeConsecutiveBadLimit ||
        (recent.length >= observeRecentWindow &&
            recentBadOrSlow >= observeRecentBadLimit);
    if (shouldCooldown) {
      nextCooldownUntil =
          sample.checkedAt + observeCooldownDuration.inMilliseconds;
    }

    return MediaCheckCacheEntry(
      key: key,
      profileId: profileId,
      profileLabel: profileLabel,
      proxyName: proxyName,
      lastResult: lastResult,
      samples: trimmed,
      modeTimes: {...modeTimes, mode: sample.checkedAt},
      observeCooldownUntil: nextCooldownUntil,
      observeBadStreak: nextBadStreak,
      observeSlowStreak: nextSlowStreak,
      observeLastReason: nextReason,
    );
  }

  bool hasMode(String mode) => modeTime(mode) != null && !isModeExpired(mode);

  /// Has cached data for mode, regardless of expiry.
  bool hasModeAny(String mode) => modeTime(mode) != null;

  /// Whether the cached result for [mode] has exceeded its TTL.
  bool isModeExpired(String mode) {
    final t = modeTime(mode);
    if (t == null || t <= 0) return true;
    final elapsed = DateTime.now().millisecondsSinceEpoch - t;
    return elapsed > _ttlForMode(mode).inMilliseconds;
  }

  Duration _ttlForMode(String mode) {
    if (mode == 'health') return cacheTTLHealth;
    final r = lastResult;
    if (r == null) return cacheTTLError;
    if (mode == 'gpt') {
      return r.chatGPT.isChatGPTAvailable ? cacheTTLSuccess : cacheTTLError;
    }
    if (mode == 'youtube') {
      if (r.youTube.isYouTubeCN) return cacheTTLSuccess;
      if (r.youTube.status == 'available') return cacheTTLSuccess;
      if (r.youTube.status == 'unknown') return cacheTTLUnknown;
      return cacheTTLError;
    }
    return cacheTTLError;
  }

  int? modeTime(String mode) {
    if (mode == 'health') {
      if (samples.isEmpty) return null;
      return samples.map((sample) => sample.checkedAt).reduce(math.max);
    }
    final value = modeTimes[mode];
    return value == null || value <= 0 ? null : value;
  }

  MediaCheckCacheEntry? clearMode(String mode) {
    final nextModeTimes = Map<String, int>.from(modeTimes)..remove(mode);
    final nextSamples = mode == 'health' ? <MediaHealthSample>[] : samples;
    MediaCheckResult? nextResult = lastResult;
    if (nextResult != null) {
      nextResult = switch (mode) {
        'gpt' => nextResult.copyWith(
          chatGPT: const MediaCheckItem(status: 'skipped'),
        ),
        'youtube' => nextResult.copyWith(
          youTube: const MediaCheckItem(status: 'skipped'),
        ),
        'health' => nextResult.copyWith(
          https: const MediaHTTPSResult(delay: -1, success: 0, total: 0),
        ),
        _ => nextResult,
      };
    }
    final hasRemainingModes =
        nextModeTimes.isNotEmpty || nextSamples.isNotEmpty;
    if (!hasRemainingModes) return null;
    return copyWith(
      lastResult: nextResult,
      samples: nextSamples,
      modeTimes: nextModeTimes,
      observeCooldownUntil: mode == 'health' ? 0 : observeCooldownUntil,
      observeBadStreak: mode == 'health' ? 0 : observeBadStreak,
      observeSlowStreak: mode == 'health' ? 0 : observeSlowStreak,
      observeLastReason: mode == 'health' ? '' : observeLastReason,
    );
  }

  MediaCheckCacheEntry copyWith({
    MediaCheckResult? lastResult,
    List<MediaHealthSample>? samples,
    Map<String, int>? modeTimes,
    int? observeCooldownUntil,
    int? observeBadStreak,
    int? observeSlowStreak,
    String? observeLastReason,
  }) {
    return MediaCheckCacheEntry(
      key: key,
      profileId: profileId,
      profileLabel: profileLabel,
      proxyName: proxyName,
      lastResult: lastResult ?? this.lastResult,
      samples: samples ?? this.samples,
      modeTimes: modeTimes ?? this.modeTimes,
      observeCooldownUntil: observeCooldownUntil ?? this.observeCooldownUntil,
      observeBadStreak: observeBadStreak ?? this.observeBadStreak,
      observeSlowStreak: observeSlowStreak ?? this.observeSlowStreak,
      observeLastReason: observeLastReason ?? this.observeLastReason,
    );
  }

  MediaHealthStats get health => MediaHealthStats.fromSamples(samples);

  bool isObservationCoolingDown([DateTime? now]) {
    if (observeCooldownUntil <= 0) return false;
    final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return observeCooldownUntil > timestamp;
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'profile-id': profileId,
      'profile-label': profileLabel,
      'proxy-name': proxyName,
      'last-result': lastResult?.toJson(),
      'samples': samples.map((sample) => sample.toJson()).toList(),
      'mode-times': modeTimes,
      'observe-cooldown-until': observeCooldownUntil,
      'observe-bad-streak': observeBadStreak,
      'observe-slow-streak': observeSlowStreak,
      'observe-last-reason': observeLastReason,
    };
  }
}

// ── MediaHealthSample ──────────────────────────────────────────────────────

class MediaHealthSample {
  const MediaHealthSample({
    required this.checkedAt,
    required this.delay,
    required this.green,
    required this.chatGPT,
  });

  factory MediaHealthSample.fromJson(Map<String, dynamic> json) {
    return MediaHealthSample(
      checkedAt: json['checked-at'] as int? ?? 0,
      delay: json['delay'] as int? ?? -1,
      green: json['green'] as bool? ?? false,
      chatGPT: json['chatgpt'] as bool? ?? false,
    );
  }

  factory MediaHealthSample.fromResult(MediaCheckResult result) {
    return MediaHealthSample(
      checkedAt: result.checkedAt,
      delay: result.https.delay,
      green: result.https.isGreen,
      chatGPT: result.chatGPT.isChatGPTAvailable,
    );
  }

  final int checkedAt;
  final int delay;
  final bool green;
  final bool chatGPT;

  Map<String, dynamic> toJson() {
    return {
      'checked-at': checkedAt,
      'delay': delay,
      'green': green,
      'chatgpt': chatGPT,
    };
  }
}

// ── MediaHealthStats ───────────────────────────────────────────────────────

@immutable
class MediaHealthStats {
  const MediaHealthStats({
    required this.sampleCount,
    required this.greenRate,
    required this.greenStreak,
    required this.chatGPTRate,
    required this.medianDelay,
    required this.score,
    this.recentFiveClean = true,
  });

  const MediaHealthStats.empty()
    : sampleCount = 0,
      greenRate = 0,
      greenStreak = 0,
      chatGPTRate = 0,
      medianDelay = -1,
      score = 0,
      recentFiveClean = true;

  factory MediaHealthStats.fromSamples(List<MediaHealthSample> samples) {
    if (samples.isEmpty) return const MediaHealthStats.empty();
    final sorted = [...samples]
      ..sort((a, b) => a.checkedAt.compareTo(b.checkedAt));
    final delays =
        sorted
            .where((sample) => sample.delay > 0)
            .map((sample) => sample.delay)
            .toList()
          ..sort();
    final greenCount = sorted.where((sample) => sample.green).length;
    final chatGPTCount = sorted.where((sample) => sample.chatGPT).length;
    var streak = 0;
    for (final sample in sorted.reversed) {
      if (!sample.green) break;
      streak++;
    }
    // Exit mechanism: check if any of the last 5 samples is non-green
    final recentFive = sorted.length >= 5
        ? sorted.sublist(sorted.length - 5)
        : sorted;
    final recentFiveClean = !recentFive.any((s) => !s.green);

    final medianDelay = delays.isEmpty ? -1 : delays[delays.length ~/ 2];
    final greenRate = greenCount / sorted.length;
    final chatGPTRate = chatGPTCount / sorted.length;
    final score =
        (greenRate * 5000).round() +
        math.min(streak, 24) * 120 +
        (chatGPTRate * 1400).round() +
        (medianDelay > 0 ? math.max(0, 1200 - medianDelay).toInt() : 0);
    return MediaHealthStats(
      sampleCount: sorted.length,
      greenRate: greenRate,
      greenStreak: streak,
      chatGPTRate: chatGPTRate,
      medianDelay: medianDelay,
      score: score,
      recentFiveClean: recentFiveClean,
    );
  }

  final int sampleCount;
  final double greenRate;
  final int greenStreak;
  final double chatGPTRate;
  final int medianDelay;
  final int score;
  final bool recentFiveClean;

  bool get hasEnoughHistory => sampleCount >= healthyMinSamples;

  bool get isLowLatency =>
      medianDelay > 0 && medianDelay <= healthyMaxMedianDelay;

  bool get isStableLowLatency =>
      hasEnoughHistory &&
      greenStreak >= healthyMinGreenStreak &&
      greenRate >= healthyMinGreenRate &&
      isLowLatency &&
      recentFiveClean;

  String get label {
    if (sampleCount == 0) return '暂无历史';
    final rate = (greenRate * 100).round();
    final delay = medianDelay > 0 ? ' · ${medianDelay}ms' : '';
    final streak = greenStreak > 0 ? ' · 连绿$greenStreak' : '';
    return '$sampleCount次 · $rate%$delay$streak';
  }
}

// ── MediaCheckResult ───────────────────────────────────────────────────────

class MediaCheckResult {
  const MediaCheckResult({
    required this.name,
    required this.chatGPT,
    required this.youTube,
    required this.https,
    required this.region,
    required this.score,
    required this.checkedAt,
    this.profileId,
    this.profileLabel = '',
  });

  factory MediaCheckResult.fromJson(Map<String, dynamic> json) {
    return MediaCheckResult(
      name: json['name'] as String? ?? '',
      chatGPT: MediaCheckItem.fromJson(
        Map<String, dynamic>.from(json['chatgpt'] as Map? ?? const {}),
      ),
      youTube: MediaCheckItem.fromJson(
        Map<String, dynamic>.from(json['youtube'] as Map? ?? const {}),
      ),
      https: MediaHTTPSResult.fromJson(
        Map<String, dynamic>.from(json['https'] as Map? ?? const {}),
      ),
      region: json['region'] as String? ?? '',
      score: json['score'] as int? ?? 0,
      checkedAt:
          json['checked-at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      profileId: json['profile-id'] as int?,
      profileLabel: json['profile-label'] as String? ?? '',
    );
  }

  factory MediaCheckResult.failed(
    String name,
    String error, {
    int? profileId,
    String profileLabel = '',
  }) {
    return MediaCheckResult(
      name: name,
      profileId: profileId,
      profileLabel: profileLabel,
      chatGPT: MediaCheckItem(status: 'failed', error: error),
      youTube: MediaCheckItem(status: 'failed', error: error),
      https: const MediaHTTPSResult(delay: -1, success: 0, total: 3),
      region: '',
      score: 0,
      checkedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  final String name;
  final int? profileId;
  final String profileLabel;
  final MediaCheckItem chatGPT;
  final MediaCheckItem youTube;
  final MediaHTTPSResult https;
  final String region;
  final int score;
  final int checkedAt;

  String get regionText => region.isEmpty ? chatGPT.region : region;

  MediaCheckResult copyWith({
    int? profileId,
    String? profileLabel,
    MediaCheckItem? chatGPT,
    MediaCheckItem? youTube,
    MediaHTTPSResult? https,
    String? region,
    int? checkedAt,
    int? score,
  }) {
    return MediaCheckResult(
      name: name,
      profileId: profileId ?? this.profileId,
      profileLabel: profileLabel ?? this.profileLabel,
      chatGPT: chatGPT ?? this.chatGPT,
      youTube: youTube ?? this.youTube,
      https: https ?? this.https,
      region: region ?? this.region,
      score: score ?? this.score,
      checkedAt: checkedAt ?? this.checkedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'profile-id': profileId,
      'profile-label': profileLabel,
      'chatgpt': chatGPT.toJson(),
      'youtube': youTube.toJson(),
      'https': https.toJson(),
      'region': region,
      'score': score,
      'checked-at': checkedAt,
    };
  }
}

// ── MediaCheckItem ─────────────────────────────────────────────────────────

class MediaCheckItem {
  const MediaCheckItem({
    required this.status,
    this.region = '',
    this.evidence = '',
    this.premiumAvailable,
    this.error = '',
  });

  factory MediaCheckItem.fromJson(Map<String, dynamic> json) {
    return MediaCheckItem(
      status: json['status'] as String? ?? 'failed',
      region: json['region'] as String? ?? '',
      evidence: json['evidence'] as String? ?? '',
      premiumAvailable: json['premium-available'] as bool?,
      error: json['error'] as String? ?? '',
    );
  }

  final String status;
  final String region;
  final String evidence;
  final bool? premiumAvailable;
  final String error;

  bool get isChatGPTAvailable => status == 'clean';

  bool get isYouTubeCN =>
      status == 'cn_confirmed' ||
      status == 'cn_inferred' ||
      status == 'unavailable' ||
      region.toUpperCase() == 'CN' ||
      evidence == 'google-cn';

  String get chatGPTCompactLabel {
    if (status == 'clean') {
      return region.isEmpty ? '解锁' : '解锁($region)';
    }
    return switch (status) {
      'blocked' => '阻断',
      'disallowed_isp' || 'unsupported' => '阻断',
      'failed' || 'timeout' || 'unknown' => '超时',
      'skipped' => 'N/A',
      _ => '超时',
    };
  }

  String get youtubeCompactLabel {
    return switch (status) {
      'cn_confirmed' => '送中',
      'cn_inferred' => '疑似送中',
      'unavailable' => '送中',
      'available' => region.isEmpty ? '解锁' : '解锁($region)',
      'unknown' || 'failed' || 'timeout' => '超时',
      'skipped' => 'N/A',
      _ => '超时',
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'region': region,
      'evidence': evidence,
      'premium-available': premiumAvailable,
      'error': error,
    };
  }
}

// ── MediaHTTPSResult ───────────────────────────────────────────────────────

class MediaHTTPSResult {
  const MediaHTTPSResult({
    required this.delay,
    required this.success,
    required this.total,
    this.values = const [],
    this.error = '',
  });

  factory MediaHTTPSResult.fromJson(Map<String, dynamic> json) {
    return MediaHTTPSResult(
      delay: json['delay'] as int? ?? -1,
      success: json['success'] as int? ?? 0,
      total: json['total'] as int? ?? 3,
      values: (json['values'] as List? ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(),
      error: json['error'] as String? ?? '',
    );
  }

  final int delay;
  final int success;
  final int total;
  final List<int> values;
  final String error;

  bool get isGreen => total > 0 && success == total && delay > 0;

  int get normalizedDelay => delay > 0 ? delay : 999999;

  String get compactLabel {
    if (delay <= 0) return '$success/$total';
    return '${delay}ms';
  }

  Map<String, dynamic> toJson() {
    return {
      'delay': delay,
      'success': success,
      'total': total,
      'values': values,
      'error': error,
    };
  }
}
