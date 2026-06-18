import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

const _mediaCheckCacheKey = 'media-check-cache-v2';
const _mediaCheckObserveSettingsKey = 'media-check-observe-settings-v1';
const _mediaCheckConcurrencyKey = 'media-check-concurrency-v1';
const _healthyMinSamples = 3;
const _healthyMinGreenStreak = 3;
const _healthyMinGreenRate = 0.85;
const _healthyMaxMedianDelay = 800;
const _observeIdleDelay = Duration(seconds: 30);
const _resultPanelMaxHeight = 460.0;
const _cacheTTLSuccess = Duration(hours: 48);
const _cacheTTLUnknown = Duration(hours: 24);
const _cacheTTLError = Duration(hours: 6);
const _cacheTTLHealth = Duration(days: 7);
const _maxCacheEntries = 500;

typedef MediaCheckConfigLoader =
    Future<Map<String, dynamic>> Function(int profileId);

Future<Map<String, dynamic>> _defaultMediaCheckConfigLoader(int profileId) {
  return coreController.getConfig(profileId);
}

String _firstNonEmpty(String first, String second) {
  return first.isNotEmpty ? first : second;
}

class ProfileMediaCheckView extends StatefulWidget {
  const ProfileMediaCheckView({
    super.key,
    required this.profiles,
    required this.initialProfile,
    this.configLoader = _defaultMediaCheckConfigLoader,
  });

  final List<Profile> profiles;
  final Profile initialProfile;
  final MediaCheckConfigLoader configLoader;

  @override
  State<ProfileMediaCheckView> createState() => _ProfileMediaCheckViewState();
}

class _ProfileMediaCheckViewState extends State<ProfileMediaCheckView>
    with WidgetsBindingObserver {
  static const _defaultConcurrency = 5;
  static const _maxConcurrency = 10;

  late Profile _profile;
  final _cacheStore = MediaCheckCacheStore();
  MediaCheckCache _cache = const MediaCheckCache(entries: {});
  MediaCheckObserveSettings _observeSettings =
      const MediaCheckObserveSettings();
  List<_MediaCheckTarget> _targets = const [];
  final Map<String, MediaCheckResult> _results = {};
  final Set<String> _running = {};
  final Set<String> _queued = {};
  Timer? _observeTimer;
  DateTime _lastInteractionAt = DateTime.now();
  var _loading = true;
  var _checking = false;
  var _healthSampling = false;
  var _cancelRequested = false;
  var _paused = false;
  var _generation = 0;
  var _concurrency = _defaultConcurrency;
  var _filter = _MediaCheckFilter.chatGPT;
  var _currentRunTotal = 0;
  var _currentRunDone = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _profile = widget.initialProfile;
    _restoreConcurrency();
    _restoreObserveSettings();
    _loadTargets();
  }

  Future<void> _restoreConcurrency() async {
    final value = await preferences.getInt(_mediaCheckConcurrencyKey);
    if (value != null && mounted) {
      setState(() {
        _concurrency = value.clamp(1, _maxConcurrency);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelRequested = true;
    _generation++;
    _observeTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Always try to run observation on lifecycle changes —
    // paused state no longer blocks health checks.
    _maybeRunObservation();
  }

  Future<void> _restoreObserveSettings() async {
    final settings = await _cacheStore.loadObserveSettings();
    if (!mounted) return;
    setState(() {
      _observeSettings = settings;
    });
    _scheduleObservation();
  }

  Future<void> _loadTargets() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _running.clear();
      _queued.clear();
      _cancelRequested = true;
      _checking = false;
      _healthSampling = false;
      _currentRunDone = 0;
      _currentRunTotal = 0;
    });

    final cache = await _cacheStore.load();
    final profiles = [_profile];
    final targets = <_MediaCheckTarget>[];
    for (final profile in profiles) {
      try {
        final configMap = await widget.configLoader(profile.id);
        final proxies = ClashConfig.fromJson(configMap).proxies;
        targets.addAll(
          proxies.map(
            (proxy) => _MediaCheckTarget(profile: profile, proxy: proxy),
          ),
        );
      } catch (_) {
        continue;
      }
    }

    if (!mounted || generation != _generation) return;
    final cachedResults = <String, MediaCheckResult>{};
    for (final target in targets) {
      final result = cache.entries[target.key]?.lastResult;
      if (result != null) {
        cachedResults[target.key] = result;
      }
    }
    setState(() {
      _cache = cache;
      _targets = targets;
      _results
        ..clear()
        ..addAll(cachedResults);
      _loading = false;
      _cancelRequested = false;
    });
    _maybeRunObservation();
  }

  Future<void> _saveResult(
    _MediaCheckTarget target,
    MediaCheckResult result,
    _MediaCheckFilter mode,
  ) async {
    final nextCache = mode == _MediaCheckFilter.green
        ? _cache.addHealthResult(
            key: target.key,
            profileId: target.profile.id,
            profileLabel: target.profile.realLabel,
            proxyName: target.proxy.name,
            result: result,
          )
        : _cache.addResult(
            key: target.key,
            profileId: target.profile.id,
            profileLabel: target.profile.realLabel,
            proxyName: target.proxy.name,
            result: result,
            mode: mode.cacheKey,
          );
    _cache = nextCache;
    await _cacheStore.save(nextCache);
  }

  /// Update in-memory cache only — no disk I/O, instant.
  void _updateCacheInMemory(
    _MediaCheckTarget target,
    MediaCheckResult result,
    _MediaCheckFilter mode,
  ) {
    final nextCache = mode == _MediaCheckFilter.green
        ? _cache.addHealthResult(
            key: target.key,
            profileId: target.profile.id,
            profileLabel: target.profile.realLabel,
            proxyName: target.proxy.name,
            result: result,
          )
        : _cache.addResult(
            key: target.key,
            profileId: target.profile.id,
            profileLabel: target.profile.realLabel,
            proxyName: target.proxy.name,
            result: result,
            mode: mode.cacheKey,
          );
    _cache = nextCache;
  }

  /// Persist current cache to disk asynchronously — fire and forget.
  void _persistCache() {
    _cacheStore.save(_cache);
  }

  Future<void> _start({_MediaCheckFilter? mode, bool automatic = false}) async {
    final runMode = mode ?? _filter;
    final healthOnly = runMode == _MediaCheckFilter.green;
    final runTargets = healthOnly && automatic
        ? _targets
              .where((target) => _cache.entries[target.key]?.lastResult != null)
              .toList()
        : _targets;
    if (_checking || runTargets.isEmpty) return;
    final generation = ++_generation;
    setState(() {
      _running.clear();
      _queued
        ..clear()
        ..addAll(runTargets.map((target) => target.key));
      _checking = true;
      _healthSampling = healthOnly;
      _cancelRequested = false;
      _currentRunDone = 0;
      _currentRunTotal = runTargets.length;
    });

    var nextIndex = 0;
    final workerCount = _concurrency.clamp(1, _maxConcurrency).toInt();

    Future<void> worker() async {
      while (mounted && generation == _generation && !_cancelRequested) {
        while (mounted && _paused && !_cancelRequested) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
        if (nextIndex >= runTargets.length) break;
        final target = runTargets[nextIndex++];
        setState(() {
          _queued.remove(target.key);
          _running.add(target.key);
        });
        try {
          final data = await coreController.mediaCheck(
            target.proxy.name,
            profileId: target.profile.id,
            healthOnly: healthOnly,
            mode: runMode.coreMode,
          );
          if (!mounted || generation != _generation || data.isEmpty) continue;
          final result =
              MediaCheckResult.fromJson(
                json.decode(data) as Map<String, dynamic>,
              ).copyWith(
                profileId: target.profile.id,
                profileLabel: target.profile.realLabel,
              );
          // Update in-memory cache synchronously, then update UI immediately
          _updateCacheInMemory(target, result, runMode);
          if (!mounted || generation != _generation) continue;
          setState(() {
            final cached = _cache.entries[target.key]?.lastResult;
            if (cached != null) _results[target.key] = cached;
          });
          // Persist to disk asynchronously — don't block the UI
          _persistCache();
        } catch (e) {
          if (!mounted || generation != _generation) continue;
          final result = MediaCheckResult.failed(
            target.proxy.name,
            '$e',
            profileId: target.profile.id,
            profileLabel: target.profile.realLabel,
          );
          _updateCacheInMemory(target, result, runMode);
          if (!mounted || generation != _generation) continue;
          setState(() {
            final cached = _cache.entries[target.key]?.lastResult;
            if (cached != null) _results[target.key] = cached;
          });
          _persistCache();
        } finally {
          if (mounted && generation == _generation) {
            setState(() {
              _running.remove(target.key);
              _currentRunDone++;
            });
          }
        }
      }
    }

    await Future.wait(List.generate(workerCount, (_) => worker()));
    if (!mounted || generation != _generation) return;
    setState(() {
      _checking = false;
      _healthSampling = false;
      _cancelRequested = false;
      _running.clear();
      _queued.clear();
    });
    if (!_cancelRequested && healthOnly) {
      final nextSettings = _observeSettings.copyWith(
        lastRunAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _setObserveSettings(nextSettings);
    }
  }

  void _cancel() {
    setState(() {
      _cancelRequested = true;
      _checking = false;
      _healthSampling = false;
      _queued.clear();
      _running.clear();
      _generation++;
    });
  }

  Future<void> _setObserveSettings(MediaCheckObserveSettings settings) async {
    setState(() {
      _observeSettings = settings;
    });
    await _cacheStore.saveObserveSettings(settings);
    _scheduleObservation();
  }

  void _toggleObservation(bool value) {
    _markInteraction();
    _setObserveSettings(_observeSettings.copyWith(enabled: value));
    if (value) {
      _maybeRunObservation();
    }
  }

  void _cycleObservationInterval() {
    _markInteraction();
    final currentIndex = MediaCheckObserveSettings.intervalOptions.indexOf(
      _observeSettings.intervalMinutes,
    );
    final nextIndex =
        (currentIndex + 1) % MediaCheckObserveSettings.intervalOptions.length;
    _setObserveSettings(
      _observeSettings.copyWith(
        intervalMinutes: MediaCheckObserveSettings.intervalOptions[nextIndex],
      ),
    );
  }

  void _markInteraction() {
    _lastInteractionAt = DateTime.now();
  }

  void _scheduleObservation() {
    _observeTimer?.cancel();
    if (!_observeSettings.enabled) return;
    _observeTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _maybeRunObservation(),
    );
  }

  Future<void> _maybeRunObservation() async {
    final idleEnough =
        DateTime.now().difference(_lastInteractionAt) >= _observeIdleDelay;
    if (!mounted ||
        !_observeSettings.enabled ||
        _checking ||
        _loading ||
        _targets.isEmpty ||
        _results.isEmpty ||
        !idleEnough ||
        !_observeSettings.isDue) {
      return;
    }
    await _start(mode: _MediaCheckFilter.green, automatic: true);
  }

  void _changeProfile(Profile profile) {
    if (_checking || profile.id == _profile.id) return;
    _markInteraction();
    setState(() {
      _profile = profile;
    });
    _loadTargets();
  }

  void _changeFilter(_MediaCheckFilter filter) {
    if (_checking || filter == _filter) return;
    _markInteraction();
    setState(() {
      _filter = filter;
    });
  }

  _MediaCheckTarget? _targetOfKey(String key) {
    for (final target in _targets) {
      if (target.key == key) return target;
    }
    return null;
  }

  bool _hasModeCache(_MediaCheckTarget target, _MediaCheckFilter mode) {
    final entry = _cache.entries[target.key];
    if (entry == null) return false;
    return entry.hasModeAny(mode.cacheKey);
  }

  bool _isModeExpired(_MediaCheckTarget target, _MediaCheckFilter mode) {
    final entry = _cache.entries[target.key];
    if (entry == null) return true;
    return entry.isModeExpired(mode.cacheKey);
  }

  int? get _lastCachedAt {
    final values = _targets
        .map((target) => _cache.entries[target.key]?.modeTime(_filter.cacheKey))
        .whereType<int>()
        .where((value) => value > 0)
        .toList();
    if (values.isEmpty) return null;
    values.sort();
    return values.last;
  }

  Future<void> _clearCurrentModeCache() async {
    if (_checking) return;
    _markInteraction();
    final targetKeys = _targets.map((target) => target.key).toSet();
    final nextCache = _cache.clearModeForKeys(
      keys: targetKeys,
      mode: _filter.cacheKey,
    );
    await _cacheStore.save(nextCache);
    if (!mounted) return;
    setState(() {
      _cache = nextCache;
      _results
        ..clear()
        ..addEntries(
          _targets.map((target) {
            final result = nextCache.entries[target.key]?.lastResult;
            return result == null ? null : MapEntry(target.key, result);
          }).whereType<MapEntry<String, MediaCheckResult>>(),
        );
    });
  }

  List<_MediaCheckRow> get _allRows {
    final rows = <_MediaCheckRow>[];
    for (final target in _targets) {
      final result = _results[target.key];
      final cacheEntry = _cache.entries[target.key];
      final hasCache = _hasModeCache(target, _filter);
      if (result == null && !_running.contains(target.key)) continue;
      if (!hasCache && !_running.contains(target.key)) continue;
      rows.add(
        _MediaCheckRow(
          target: target,
          result: result,
          health: cacheEntry?.health ?? const MediaHealthStats.empty(),
          running: _running.contains(target.key),
          expired: _isModeExpired(target, _filter),
        ),
      );
    }
    rows.sort((a, b) {
      final aScore = a.rankScore(_filter);
      final bScore = b.rankScore(_filter);
      if (aScore != bScore) return bScore.compareTo(aScore);
      return a.delay.compareTo(b.delay);
    });
    return rows;
  }

  List<_MediaCheckRow> get _rows {
    return _allRows.where((row) {
      final result = row.result;
      if (result == null) return true;
      return _filter.matches(result, row.health);
    }).toList();
  }

  _MediaCheckSummary get _summary {
    return _MediaCheckSummary.fromTargets(_targets, _cache);
  }

  int get _cachedCountForMode {
    return _targets.where((target) => _hasModeCache(target, _filter)).length;
  }

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final progress = _currentRunTotal == 0
        ? 0.0
        : _currentRunDone / _currentRunTotal;
    final rows = _rows;
    final summary = _summary;

    return CommonScaffold(
      title: '节点批量检测',
      backgroundColor: surge.background,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _markInteraction(),
        onPointerMove: (_) => _markInteraction(),
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 112 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MediaCheckControlCard(
                  profiles: widget.profiles,
                  profile: _profile,
                  filter: _filter,
                  loading: _loading,
                  checking: _checking,
                  paused: _paused,
                  targetCount: _targets.length,
                  cachedCount: _cachedCountForMode,
                  runningCount: _running.length,
                  concurrency: _concurrency,
                  observing: _observeSettings.enabled,
                  observeIntervalLabel: _observeSettings.intervalLabel,
                  healthSampling: _healthSampling,
                  progress: progress,
                  onProfileChanged: _checking ? null : _changeProfile,
                  onFilterChanged: _checking ? null : _changeFilter,
                  onConcurrencyChanged: _checking
                      ? null
                      : (value) {
                          _markInteraction();
                          setState(() {
                            _concurrency = value;
                          });
                          preferences.setInt(_mediaCheckConcurrencyKey, value);
                        },
                  onStart: () {
                    _markInteraction();
                    _start();
                  },
                  onCancel: _cancel,
                  onObservingChanged: _toggleObservation,
                  onObserveIntervalTap: _checking
                      ? null
                      : _cycleObservationInterval,
                ),
                const SizedBox(height: 12),
                _MediaCheckFilterGrid(
                  filter: _filter,
                  summary: summary,
                  onChanged: _changeFilter,
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (rows.isEmpty && _running.isEmpty && _queued.isEmpty)
                  _EmptyMediaCheckState(targetCount: _targets.length)
                else if (rows.isEmpty)
                  _EmptyFilteredState(filter: _filter)
                else
                  _MediaCheckResultList(
                    rows: rows,
                    filter: _filter,
                    cached: !_checking && _cachedCountForMode > 0,
                    lastCachedAt: _lastCachedAt,
                    onClear: _checking ? null : _clearCurrentModeCache,
                  ),
                for (final key in _running)
                  if (_targetOfKey(key) case final target?)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _MediaCheckPendingCard(target: target),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaCheckControlCard extends StatelessWidget {
  const _MediaCheckControlCard({
    required this.profiles,
    required this.profile,
    required this.filter,
    required this.loading,
    required this.checking,
    required this.paused,
    required this.targetCount,
    required this.cachedCount,
    required this.runningCount,
    required this.concurrency,
    required this.observing,
    required this.observeIntervalLabel,
    required this.healthSampling,
    required this.progress,
    required this.onProfileChanged,
    required this.onFilterChanged,
    required this.onConcurrencyChanged,
    required this.onStart,
    required this.onCancel,
    required this.onObservingChanged,
    required this.onObserveIntervalTap,
  });

  final List<Profile> profiles;
  final Profile profile;
  final _MediaCheckFilter filter;
  final bool loading;
  final bool checking;
  final bool paused;
  final int targetCount;
  final int cachedCount;
  final int runningCount;
  final int concurrency;
  final bool observing;
  final String observeIntervalLabel;
  final bool healthSampling;
  final double progress;
  final ValueChanged<Profile>? onProfileChanged;
  final ValueChanged<_MediaCheckFilter>? onFilterChanged;
  final ValueChanged<int>? onConcurrencyChanged;
  final VoidCallback onStart;
  final VoidCallback onCancel;
  final ValueChanged<bool> onObservingChanged;
  final VoidCallback? onObserveIntervalTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeCard(
      shadow: true,
      backgroundColor: surge.elevatedCard,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '节点体检',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: surge.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _MediaCheckRunButton(
                checking: checking,
                onTap: loading || targetCount == 0
                    ? null
                    : checking
                    ? onCancel
                    : onStart,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ProfileSelector(
                  profiles: profiles,
                  profile: profile,
                  enabled: onProfileChanged != null,
                  onChanged: onProfileChanged,
                ),
              ),
              const SizedBox(width: 8),
              _ModeDropdown(
                value: filter,
                enabled: onFilterChanged != null,
                onChanged: onFilterChanged,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ControlMetric(label: '节点', value: '$targetCount'),
              const SizedBox(width: 8),
              _ControlMetric(label: '缓存', value: '$cachedCount'),
              const SizedBox(width: 8),
              _ControlMetric(label: '并发', value: '$concurrency'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Flexible(
                flex: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: checking ? progress : (cachedCount > 0 ? 1 : 0),
                    minHeight: 5,
                    backgroundColor: surge.textSecondary.withValues(alpha: 0.1),
                    color: checking ? surge.primary : surge.green,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                checking
                    ? '${(progress * 100).clamp(0, 100).round()}%'
                    : cachedCount > 0
                    ? '已缓存'
                    : '未检测',
                style: context.textTheme.labelSmall?.copyWith(
                  color: surge.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: Slider(
                  value: concurrency.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  onChanged: onConcurrencyChanged == null
                      ? null
                      : (value) => onConcurrencyChanged!(value.round()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ObservationControl(
            observing: observing,
            intervalLabel: observeIntervalLabel,
            enabled: !checking,
            onChanged: onObservingChanged,
            onIntervalTap: onObserveIntervalTap,
          ),
        ],
      ),
    );
  }
}

class _ObservationControl extends StatelessWidget {
  const _ObservationControl({
    required this.observing,
    required this.intervalLabel,
    required this.enabled,
    required this.onChanged,
    required this.onIntervalTap,
  });

  final bool observing;
  final String intervalLabel;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onIntervalTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: observing ? surge.green.withValues(alpha: 0.1) : surge.fill,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: observing
              ? surge.green.withValues(alpha: 0.22)
              : surge.separator,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.monitor_heart_outlined,
            size: 16,
            color: observing ? surge.green : surge.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '健康观测',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelMedium?.copyWith(
                color: observing ? surge.green : surge.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          TextButton(
            onPressed: enabled ? onIntervalTap : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 30),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: observing ? surge.green : surge.textSecondary,
            ),
            child: Text(
              intervalLabel,
              style: context.textTheme.labelSmall?.copyWith(
                color: observing ? surge.green : surge.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          SurgeSwitch(value: observing, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}

class _ProfileSelector extends StatelessWidget {
  const _ProfileSelector({
    required this.profiles,
    required this.profile,
    required this.enabled,
    required this.onChanged,
  });

  final List<Profile> profiles;
  final Profile profile;
  final bool enabled;
  final ValueChanged<Profile>? onChanged;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: surge.fill,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: surge.separator, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Profile>(
          value: profile,
          isExpanded: true,
          borderRadius: BorderRadius.circular(surge.radii.card),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: surge.textSecondary,
            size: 20,
          ),
          items: [
            for (final item in profiles)
              DropdownMenuItem(
                value: item,
                child: Text(
                  item.realLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: surge.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
          ],
          onChanged: !enabled || onChanged == null
              ? null
              : (value) {
                  if (value != null) onChanged!(value);
                },
        ),
      ),
    );
  }
}

class _ModeDropdown extends StatelessWidget {
  const _ModeDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final _MediaCheckFilter value;
  final bool enabled;
  final ValueChanged<_MediaCheckFilter>? onChanged;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: surge.fill,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: surge.separator, width: 0.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_MediaCheckFilter>(
          value: value,
          borderRadius: BorderRadius.circular(surge.radii.card),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: surge.textSecondary,
            size: 20,
          ),
          items: [
            for (final item in _MediaCheckFilter.values)
              DropdownMenuItem(
                value: item,
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: surge.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
          ],
          onChanged: !enabled || onChanged == null
              ? null
              : (value) {
                  if (value != null) onChanged!(value);
                },
        ),
      ),
    );
  }
}

class _ControlMetric extends StatelessWidget {
  const _ControlMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Expanded(
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: surge.fill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                color: surge.textSecondary,
                fontSize: 10,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: context.textTheme.titleSmall?.copyWith(
                color: surge.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaCheckFilterGrid extends StatelessWidget {
  const _MediaCheckFilterGrid({
    required this.filter,
    required this.summary,
    required this.onChanged,
  });

  final _MediaCheckFilter filter;
  final _MediaCheckSummary summary;
  final ValueChanged<_MediaCheckFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 16) / 3;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in _MediaCheckFilter.values)
              SizedBox(
                width: width,
                child: _FilterTile(
                  filter: item,
                  selected: filter == item,
                  value: summary.valueFor(item),
                  subtitle: summary.subtitleFor(item),
                  onTap: () => onChanged(item),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.filter,
    required this.selected,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  final _MediaCheckFilter filter;
  final bool selected;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = filter.color(surge);
    final textColor = selected ? color : surge.textPrimary;
    return SurgeCard(
      shadow: false,
      borderRadius: 14,
      backgroundColor: selected
          ? surge.fill.withValues(alpha: 0.72)
          : surge.card,
      border: Border.all(
        color: selected
            ? color.withValues(alpha: 0.34)
            : surge.separator.withValues(alpha: 0.85),
        width: 0.5,
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(filter.icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  filter.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? color.withValues(alpha: 0.82)
                        : surge.textSecondary,
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                value,
                style: context.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediaCheckResultList extends StatelessWidget {
  const _MediaCheckResultList({
    required this.rows,
    required this.filter,
    required this.cached,
    required this.lastCachedAt,
    required this.onClear,
  });

  final List<_MediaCheckRow> rows;
  final _MediaCheckFilter filter;
  final bool cached;
  final int? lastCachedAt;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final cacheText = lastCachedAt == null
        ? '无缓存'
        : '上次 ${_formatCacheTime(lastCachedAt!)}';
    return SurgeCard(
      shadow: false,
      backgroundColor: surge.elevatedCard,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    filter.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: surge.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '清除缓存',
                  onPressed: cached ? onClear : null,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  style: IconButton.styleFrom(
                    fixedSize: const Size(32, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: surge.textSecondary,
                    disabledForegroundColor: surge.textSecondary.withValues(
                      alpha: 0.35,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  cacheText,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: surge.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: _resultPanelMaxHeight,
              ),
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: surge.fill,
                  borderRadius: BorderRadius.circular(surge.radii.list),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(surge.radii.list),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      scrollbarTheme: const ScrollbarThemeData(
                        mainAxisMargin: 8,
                      ),
                    ),
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (final row in rows)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _MediaCheckResultCard(
                                  row: row,
                                  filter: filter,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCacheTime(int milliseconds) {
    final time = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _MediaCheckResultCard extends StatelessWidget {
  const _MediaCheckResultCard({required this.row, required this.filter});

  final _MediaCheckRow row;
  final _MediaCheckFilter filter;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final result = row.result;
    return SurgeCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      shadow: false,
      borderRadius: surge.radii.list,
      border: Border.all(color: surge.separator, width: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: EmojiText(
                  row.target.proxy.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: surge.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (row.target.profile.realLabel.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  row.target.profile.realLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: surge.textSecondary,
                    fontSize: 10,
                    letterSpacing: 0,
                  ),
                ),
              ],
              if (row.expired) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: surge.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '已过期',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: surge.orange,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (row.running && result == null)
            const _MediaCheckInlineLoading()
          else if (result != null)
            switch (filter) {
              _MediaCheckFilter.chatGPT => _SingleResultLine(
                color: result.chatGPT.statusColor(surge),
                label: result.chatGPT.chatGPTCompactLabel,
                meta: result.regionText,
                icon: Icons.psychology_alt_rounded,
              ),
              _MediaCheckFilter.youTubeCN => _SingleResultLine(
                color: result.youTube.youtubeColor(surge),
                label: result.youTube.youtubeCompactLabel,
                meta: result.youTube.evidence,
                icon: Icons.smart_display_rounded,
              ),
              _MediaCheckFilter.green => _HealthResultLine(
                result: result,
                health: row.health,
              ),
            },
        ],
      ),
    );
  }
}

class _SingleResultLine extends StatelessWidget {
  const _SingleResultLine({
    required this.color,
    required this.label,
    required this.meta,
    required this.icon,
  });

  final Color color;
  final String label;
  final String meta;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelMedium?.copyWith(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          if (meta.isNotEmpty)
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.copyWith(
                color: surge.textSecondary,
                fontSize: 10,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }
}

class _HealthResultLine extends StatelessWidget {
  const _HealthResultLine({required this.result, required this.health});

  final MediaCheckResult result;
  final MediaHealthStats health;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = result.https.statusColor(surge);
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.eco_outlined, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  flex: 3,
                  child: Text(
                    result.https.compactLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 4,
                  child: Text(
                    health.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: surge.textSecondary,
                      fontSize: 10,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaCheckInlineLoading extends StatelessWidget {
  const _MediaCheckInlineLoading();

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Row(
      children: [
        SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: surge.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '检测中',
          style: context.textTheme.labelSmall?.copyWith(
            color: surge.textSecondary,
            fontSize: 11,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _MediaCheckPendingCard extends StatelessWidget {
  const _MediaCheckPendingCard({required this.target});

  final _MediaCheckTarget target;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shadow: false,
      borderRadius: surge.radii.list,
      border: Border.all(color: surge.separator, width: 0.5),
      child: Row(
        children: [
          Expanded(
            child: EmojiText(
              target.proxy.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium?.copyWith(
                color: surge.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const _MediaCheckInlineLoading(),
        ],
      ),
    );
  }
}

class _EmptyMediaCheckState extends StatelessWidget {
  const _EmptyMediaCheckState({required this.targetCount});

  final int targetCount;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(
        targetCount == 0 ? '没有可检测节点' : '检测结果会展示在这里',
        textAlign: TextAlign.center,
        style: context.textTheme.bodySmall?.copyWith(
          color: surge.textSecondary,
          fontSize: 12,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _EmptyFilteredState extends StatelessWidget {
  const _EmptyFilteredState({required this.filter});

  final _MediaCheckFilter filter;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        filter == _MediaCheckFilter.green ? '历史样本不足' : '暂无${filter.label}结果',
        textAlign: TextAlign.center,
        style: context.textTheme.bodySmall?.copyWith(
          color: surge.textSecondary,
          fontSize: 12,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MediaCheckRunButton extends StatelessWidget {
  const _MediaCheckRunButton({required this.checking, required this.onTap});

  final bool checking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = checking ? surge.red : surge.primary;
    return Tooltip(
      message: checking ? '取消检测' : '开始检测',
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(
          checking ? Icons.stop_rounded : Icons.play_arrow_rounded,
          size: 15,
        ),
        label: Text(checking ? '取消' : '开始'),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          foregroundColor: surge.onPrimary,
          disabledForegroundColor: surge.onPrimary.withValues(alpha: 0.7),
          minimumSize: const Size(56, 30),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(surge.radii.button),
          ),
          textStyle: context.textTheme.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

enum _MediaCheckFilter {
  chatGPT('GPT', 'GPT 解锁', '解锁地区', Icons.psychology_alt_rounded),
  youTubeCN('YouTube', 'YouTube 送中', '送中候选', Icons.smart_display_rounded),
  green('健康', '全绿低延迟', '历史稳定', Icons.eco_outlined);

  final String label;
  final String resultTitle;
  final String subtitle;
  final IconData icon;

  const _MediaCheckFilter(this.label, this.resultTitle, this.subtitle, this.icon);

  String? get badgeLabel {
    return switch (this) {
      _MediaCheckFilter.chatGPT => 'GPT',
      _MediaCheckFilter.youTubeCN => null,
      _MediaCheckFilter.green => null,
    };
  }

  String get coreMode {
    return switch (this) {
      _MediaCheckFilter.chatGPT => 'gpt',
      _MediaCheckFilter.youTubeCN => 'youtube',
      _MediaCheckFilter.green => 'health',
    };
  }

  String get cacheKey {
    return switch (this) {
      _MediaCheckFilter.chatGPT => 'gpt',
      _MediaCheckFilter.youTubeCN => 'youtube',
      _MediaCheckFilter.green => 'health',
    };
  }

  bool matches(MediaCheckResult result, MediaHealthStats? health) {
    return switch (this) {
      _MediaCheckFilter.chatGPT => result.chatGPT.status != 'skipped',
      _MediaCheckFilter.youTubeCN => result.youTube.status != 'skipped',
      _MediaCheckFilter.green => (health?.sampleCount ?? 0) > 0,
    };
  }

  Color color(SurgeTheme surge) {
    return switch (this) {
      _MediaCheckFilter.chatGPT => surge.purple,
      _MediaCheckFilter.youTubeCN => surge.orange,
      _MediaCheckFilter.green => surge.green,
    };
  }
}

class _MediaCheckTarget {
  const _MediaCheckTarget({required this.profile, required this.proxy});

  final Profile profile;
  final Proxy proxy;

  String get key => '${profile.id}::${proxy.name}';
}

class _MediaCheckRow {
  const _MediaCheckRow({
    required this.target,
    required this.result,
    required this.health,
    required this.running,
    this.expired = false,
  });

  final _MediaCheckTarget target;
  final MediaCheckResult? result;
  final MediaHealthStats health;
  final bool running;
  final bool expired;

  int get delay => result?.https.normalizedDelay ?? 999999;

  /// Independent ranking per mode — no cross-reference to other modes.
  int rankScore(_MediaCheckFilter filter) {
    final r = result;
    if (r == null) return -1;
    final d = delay;
    return switch (filter) {
      // ChatGPT: available first (sorted by delay asc), then others (sorted by delay asc)
      _MediaCheckFilter.chatGPT =>
        r.chatGPT.isChatGPTAvailable
            ? 200000 - d.clamp(0, 199999)
            : -d,
      // YouTube: 送中 → available → unknown → failed/timeout; each group sorted by delay asc
      _MediaCheckFilter.youTubeCN =>
        r.youTube.isYouTubeCN
            ? 400000 - d.clamp(0, 399999)
            : r.youTube.status == 'available'
                ? 300000 - d.clamp(0, 299999)
                : r.youTube.status == 'unknown'
                    ? 200000 - d.clamp(0, 199999)
                    : -d,
      // Green: stable-low-latency first → others; each sorted by median delay asc
      _MediaCheckFilter.green =>
        health.isStableLowLatency
            ? 200000 -
                (health.medianDelay > 0 ? health.medianDelay : 999999)
                    .clamp(0, 199999)
            : -(health.medianDelay > 0 ? health.medianDelay : 999999),
    };
  }
}

class _MediaCheckSummary {
  const _MediaCheckSummary({
    required this.total,
    required this.chatGPT,
    required this.youtubeCN,
    required this.green,
  });

  factory _MediaCheckSummary.fromTargets(
    List<_MediaCheckTarget> targets,
    MediaCheckCache cache,
  ) {
    var total = 0;
    var chatGPT = 0;
    var youtubeCN = 0;
    var green = 0;
    for (final target in targets) {
      final entry = cache.entries[target.key];
      final result = entry?.lastResult;
      if (entry == null || result == null) continue;
      total++;
      if (entry.hasMode('gpt') && result.chatGPT.isChatGPTAvailable) {
        chatGPT++;
      }
      if (entry.hasMode('youtube') && result.youTube.isYouTubeCN) {
        youtubeCN++;
      }
      if (entry.hasMode('health') && entry.health.isStableLowLatency) {
        green++;
      }
    }
    return _MediaCheckSummary(
      total: total,
      chatGPT: chatGPT,
      youtubeCN: youtubeCN,
      green: green,
    );
  }

  final int total;
  final int chatGPT;
  final int youtubeCN;
  final int green;

  String valueFor(_MediaCheckFilter filter) {
    return switch (filter) {
      _MediaCheckFilter.chatGPT => '$chatGPT',
      _MediaCheckFilter.youTubeCN => '$youtubeCN',
      _MediaCheckFilter.green => '$green',
    };
  }

  String subtitleFor(_MediaCheckFilter filter) => filter.subtitle;
}

class MediaCheckCacheStore {
  Future<MediaCheckCache> load() async {
    final raw = await preferences.getString(_mediaCheckCacheKey);
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
    await preferences.setString(_mediaCheckCacheKey, json.encode(cache));
  }

  Future<MediaCheckObserveSettings> loadObserveSettings() async {
    final raw = await preferences.getString(_mediaCheckObserveSettingsKey);
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
      _mediaCheckObserveSettingsKey,
      json.encode(settings),
    );
  }
}

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

  static const intervalOptions = [20, 40, 60, 120];

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
      final allExpired = e.modeTimes.keys.every((mode) => e.isModeExpired(mode));
      if (allExpired && e.samples.isEmpty) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      nextEntries.remove(key);
    }
    return MediaCheckCache(entries: nextEntries);
  }

  /// Evict oldest entries when exceeding [_maxCacheEntries].
  MediaCheckCache _enforceCapacity() {
    if (entries.length <= _maxCacheEntries) return this;
    final sorted = entries.entries.toList()
      ..sort((a, b) {
        int maxTime(Map<String, int> m) =>
            m.values.fold(0, (prev, v) => v > prev ? v : prev);
        return maxTime(a.value.modeTimes).compareTo(maxTime(b.value.modeTimes));
      });
    final nextEntries = Map<String, MediaCheckCacheEntry>.from(entries);
    while (sorted.length > _maxCacheEntries) {
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

class MediaCheckCacheEntry {
  const MediaCheckCacheEntry({
    required this.key,
    required this.profileId,
    required this.profileLabel,
    required this.proxyName,
    required this.samples,
    this.modeTimes = const {},
    this.lastResult,
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
    );
  }

  final String key;
  final int profileId;
  final String profileLabel;
  final String proxyName;
  final MediaCheckResult? lastResult;
  final List<MediaHealthSample> samples;
  final Map<String, int> modeTimes;

  MediaCheckCacheEntry addModeResult(MediaCheckResult result, String mode) {
    final merged = switch (mode) {
      'gpt' => (lastResult ?? result).copyWith(
        chatGPT: result.chatGPT,
        region: _firstNonEmpty(result.chatGPT.region, lastResult?.region ?? ''),
        checkedAt: result.checkedAt,
      ),
      'youtube' => (lastResult ?? result).copyWith(
        youTube: result.youTube,
        region: _firstNonEmpty(result.youTube.region, lastResult?.region ?? ''),
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
    return MediaCheckCacheEntry(
      key: key,
      profileId: profileId,
      profileLabel: profileLabel,
      proxyName: proxyName,
      lastResult: lastResult,
      samples: trimmed,
      modeTimes: {...modeTimes, mode: sample.checkedAt},
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
    if (mode == 'health') return _cacheTTLHealth;
    final r = lastResult;
    if (r == null) return _cacheTTLError;
    if (mode == 'gpt') {
      return r.chatGPT.isChatGPTAvailable ? _cacheTTLSuccess : _cacheTTLError;
    }
    if (mode == 'youtube') {
      if (r.youTube.isYouTubeCN) return _cacheTTLSuccess;
      if (r.youTube.status == 'available') return _cacheTTLSuccess;
      if (r.youTube.status == 'unknown') return _cacheTTLUnknown;
      return _cacheTTLError;
    }
    return _cacheTTLError;
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
    );
  }

  MediaCheckCacheEntry copyWith({
    MediaCheckResult? lastResult,
    List<MediaHealthSample>? samples,
    Map<String, int>? modeTimes,
  }) {
    return MediaCheckCacheEntry(
      key: key,
      profileId: profileId,
      profileLabel: profileLabel,
      proxyName: proxyName,
      lastResult: lastResult ?? this.lastResult,
      samples: samples ?? this.samples,
      modeTimes: modeTimes ?? this.modeTimes,
    );
  }

  MediaHealthStats get health => MediaHealthStats.fromSamples(samples);

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'profile-id': profileId,
      'profile-label': profileLabel,
      'proxy-name': proxyName,
      'last-result': lastResult?.toJson(),
      'samples': samples.map((sample) => sample.toJson()).toList(),
      'mode-times': modeTimes,
    };
  }
}

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

  bool get hasEnoughHistory => sampleCount >= _healthyMinSamples;

  bool get isLowLatency =>
      medianDelay > 0 && medianDelay <= _healthyMaxMedianDelay;

  bool get isStableLowLatency =>
      hasEnoughHistory &&
      greenStreak >= _healthyMinGreenStreak &&
      greenRate >= _healthyMinGreenRate &&
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

  Color statusColor(SurgeTheme surge) {
    return switch (status) {
      'clean' => surge.green,
      'unsupported' || 'blocked' || 'disallowed_isp' => surge.red,
      'failed' || 'timeout' || 'unknown' => surge.orange,
      _ => surge.inactive,
    };
  }

  Color youtubeColor(SurgeTheme surge) {
    return switch (status) {
      'cn_confirmed' || 'cn_inferred' || 'unavailable' => surge.orange,
      'available' => surge.green,
      'failed' || 'timeout' || 'unknown' => surge.orange,
      _ => surge.inactive,
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

  Color statusColor(SurgeTheme surge) {
    if (isGreen) return surge.green;
    if (success > 0) return surge.orange;
    return surge.red;
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
