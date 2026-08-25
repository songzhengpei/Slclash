import 'dart:async';
import 'dart:convert';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

int _regionPriority(String region) {
  if (region.toUpperCase() == 'SG') return 2;
  if (region.toUpperCase() == 'US') return 1;
  return 0;
}

// ── Page-local constants ──────────────────────────────────────────────────

const _mediaCheckConcurrencyKey = 'media-check-concurrency-v1';
const _resultPanelMaxHeight = 470.0;

typedef MediaCheckConfigLoader =
    Future<Map<String, dynamic>> Function(int profileId);

Future<Map<String, dynamic>> _defaultMediaCheckConfigLoader(int profileId) {
  return coreController.getConfig(profileId);
}

// ── UI color extensions (SurgeTheme-dependent, kept in view layer) ────────

extension MediaCheckItemColors on MediaCheckItem {
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
}

extension MediaHTTPSResultColors on MediaHTTPSResult {
  Color statusColor(SurgeTheme surge) {
    if (isGreen) return surge.green;
    if (success > 0) return surge.orange;
    return surge.red;
  }
}

class ProfileMediaCheckView extends ConsumerStatefulWidget {
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
  ConsumerState<ProfileMediaCheckView> createState() =>
      _ProfileMediaCheckViewState();
}

class _ProfileMediaCheckViewState extends ConsumerState<ProfileMediaCheckView> {
  static const _defaultConcurrency = 5;
  static const _maxConcurrency = 10;

  void Function()? _removeGroupsListener;

  late Profile _profile;
  final _cacheStore = MediaCheckCacheStore();
  MediaCheckCache _cache = const MediaCheckCache(entries: {});
  List<_MediaCheckTarget> _targets = const [];
  final Map<String, MediaCheckResult> _results = {};
  final Set<String> _running = {};
  final Set<String> _queued = {};
  var _loading = true;
  var _checking = false;
  var _healthSampling = false;
  var _cancelRequested = false;
  final _paused = false;
  var _generation = 0;
  var _concurrency = _defaultConcurrency;
  var _filter = _MediaCheckFilter.chatGPT;
  var _currentRunTotal = 0;
  var _currentRunDone = 0;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _restoreConcurrency();
    _loadTargets();
    // Persist the initial profile selection for background health observation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      globalState.container
          .read(mediaCheckSelectedProfileIdProvider.notifier)
          .select(_profile.id);
    });
    // Refresh targets when groups data updates (e.g. after profile switch)
    final sub = globalState.container.listen(
      groupsProvider,
      (_, _) => _loadTargets(),
    );
    _removeGroupsListener = sub.close;
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
    _cancelRequested = true;
    _generation++;
    _removeGroupsListener?.call();
    super.dispose();
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
    final targets = <_MediaCheckTarget>[];
    final proxies = await _loadRuntimeLeafProxies();
    targets.addAll(
      proxies.map(
        (proxy) => _MediaCheckTarget(profile: _profile, proxy: proxy),
      ),
    );

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
  }

  Future<List<Proxy>> _loadRuntimeLeafProxies() async {
    final currentProfileId = globalState.container.read(
      currentProfileIdProvider,
    );
    final groups = globalState.container.read(groupsProvider);
    return loadProfileLeafProxies(
      profileId: _profile.id,
      currentProfileId: currentProfileId,
      configLoader: widget.configLoader,
      fallbackGroups: groups,
    );
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

  Future<void> _start({_MediaCheckFilter? mode}) async {
    final runMode = mode ?? _filter;
    final healthOnly = runMode == _MediaCheckFilter.green;
    final runTargets = _targets;
    if (_checking || runTargets.isEmpty) {
      return;
    }
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
          final decoded = json.decode(data) as Map<String, dynamic>;
          final result = MediaCheckResult.fromJson(decoded).copyWith(
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

  void _changeProfile(Profile profile) {
    if (_checking || profile.id == _profile.id) return;
    setState(() {
      _profile = profile;
    });
    _loadTargets();
    // Persist the selected profile for background health observation
    globalState.container
        .read(mediaCheckSelectedProfileIdProvider.notifier)
        .select(profile.id);
  }

  void _changeFilter(_MediaCheckFilter filter) {
    if (_checking || filter == _filter) return;
    setState(() {
      _filter = filter;
    });
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

    // ── Sort ───────────────────────────────────────────────────────────────
    rows.sort((a, b) {
      final aScore = a.rankScore(_filter);
      final bScore = b.rankScore(_filter);
      if (aScore != bScore) return bScore.compareTo(aScore);
      // ── Within-group tiebreaker — per mode ───────────────────────────
      switch (_filter) {
        case _MediaCheckFilter.chatGPT:
          // Unlocked group: SG/US first → region asc → name asc
          final aR = (a.result?.chatGPT.region ?? '').toUpperCase();
          final bR = (b.result?.chatGPT.region ?? '').toUpperCase();
          final ap = _regionPriority(aR);
          final bp = _regionPriority(bR);
          if (ap != bp) return bp.compareTo(ap);
          if (aR != bR) return aR.compareTo(bR);
          return a.target.proxy.name.compareTo(b.target.proxy.name);
        case _MediaCheckFilter.youTubeCN:
          // Same-group: by name asc
          return a.target.proxy.name.compareTo(b.target.proxy.name);
        case _MediaCheckFilter.green:
          return a.target.proxy.name.compareTo(b.target.proxy.name);
      }
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

    final schedulerState = ref.watch(healthObservationSchedulerProvider);

    return CommonScaffold(
      title: context.appLocalizations.mediaCheck,
      backgroundColor: surge.background,
      appBarActions: const [],
      body: Align(
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
                summary: summary,
                observing: schedulerState.enabled,
                observeIntervalLabel: schedulerState.intervalLabel,
                healthSampling: _healthSampling,
                progress: progress,
                onProfileChanged: _checking ? null : _changeProfile,
                onFilterChanged: _checking ? null : _changeFilter,
                onConcurrencyChanged: _checking
                    ? null
                    : (value) {
                        setState(() {
                          _concurrency = value;
                        });
                        preferences.setInt(_mediaCheckConcurrencyKey, value);
                      },
                onStart: () {
                  _start();
                },
                onCancel: _cancel,
                onObservingChanged: (value) {
                  ref
                      .read(healthObservationSchedulerProvider.notifier)
                      .setEnabled(value);
                },
                onObserveIntervalTap: _checking
                    ? null
                    : () {
                        final currentInterval = schedulerState.intervalMinutes;
                        final options =
                            HealthObservationScheduler.observeIntervalOptions;
                        final currentIndex = options.indexOf(currentInterval);
                        final nextIndex = (currentIndex + 1) % options.length;
                        ref
                            .read(healthObservationSchedulerProvider.notifier)
                            .setIntervalMinutes(options[nextIndex]);
                      },
                onSummaryFilterChanged: _checking ? null : _changeFilter,
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (rows.isEmpty && _allRows.isEmpty)
                _MediaCheckEmptyResultCard(
                  title: _filter.subtitle(context),
                  message: _targets.isEmpty
                      ? context.appLocalizations.noNodesToCheck
                      : context.appLocalizations.checkResultsAppearHere,
                )
              else if (rows.isEmpty)
                _MediaCheckEmptyResultCard(
                  title: _filter.subtitle(context),
                  message: _filter == _MediaCheckFilter.green
                      ? context.appLocalizations.notEnoughHistory
                      : context.appLocalizations.noFilteredResults(
                          _filter.label(context),
                        ),
                )
              else if (rows.isNotEmpty)
                _MediaCheckResultList(
                  rows: rows,
                  filter: _filter,
                  cached: !_checking && _cachedCountForMode > 0,
                  lastCachedAt: _lastCachedAt,
                  onClear: _checking ? null : _clearCurrentModeCache,
                ),
            ],
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
    required this.summary,
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
    required this.onSummaryFilterChanged,
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
  final _MediaCheckSummary summary;
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
  final ValueChanged<_MediaCheckFilter>? onSummaryFilterChanged;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeCard(
      shadow: true,
      backgroundColor: surge.elevatedCard,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  key: const Key('media-check-header-icon'),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: surge.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    SurgeIcons.mediaCheck,
                    size: 16,
                    color: surge.primary.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    context.appLocalizations.nodeCheckup,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.mediaCheckTitle.copyWith(
                      color: surge.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 11,
                child: _ProfileSelector(
                  profiles: profiles,
                  profile: profile,
                  enabled: onProfileChanged != null,
                  onChanged: onProfileChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 9,
                child: _ModeDropdown(
                  value: filter,
                  enabled: onFilterChanged != null,
                  onChanged: onFilterChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Divider(height: 1, color: surge.separator),
          const SizedBox(height: 8),
          _ControlMetricsLine(
            targetCount: targetCount,
            cachedCount: cachedCount,
            concurrency: concurrency,
            runningCount: runningCount,
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: surge.separator),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 22,
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: checking
                                ? progress
                                : (cachedCount > 0 ? 1 : 0),
                            minHeight: 5,
                            backgroundColor: surge.textSecondary.withValues(
                              alpha: 0.1,
                            ),
                            color: checking ? surge.primary : surge.green,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        checking
                            ? '${(progress * 100).clamp(0, 100).round()}%'
                            : cachedCount > 0
                            ? context.appLocalizations.cached
                            : context.appLocalizations.notChecked,
                        style: context.typography.badgeLabel.copyWith(
                          color: surge.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 96,
                height: 32,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(trackHeight: 5),
                  child: Slider(
                    padding: EdgeInsets.zero,
                    value: concurrency.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: onConcurrencyChanged == null
                        ? null
                        : (value) => onConcurrencyChanged!(value.round()),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Divider(height: 1, color: surge.separator),
          _ObservationControl(
            observing: observing,
            intervalLabel: observeIntervalLabel,
            enabled: !checking,
            onChanged: onObservingChanged,
            onIntervalTap: onObserveIntervalTap,
          ),
          Divider(height: 1, color: surge.separator),
          const SizedBox(height: 10),
          _MediaCheckInlineStats(
            filter: filter,
            summary: summary,
            onChanged: onSummaryFilterChanged,
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
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Icon(
            SurgeIcons.monitorHealth,
            size: SurgeIconSize.compact,
            color: surge.green,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.appLocalizations.healthMonitoring,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.controlLabel.copyWith(
                color: observing ? surge.green : surge.textPrimary,
              ),
            ),
          ),
          TextButton(
            onPressed: enabled ? onIntervalTap : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: surge.green,
            ),
            child: Text(
              intervalLabel,
              style: context.typography.mediaObservationInterval.copyWith(
                color: observing ? surge.green : surge.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
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
    return SoftOsSelectPill<Profile>(
      value: profile,
      semanticLabel: context.appLocalizations.selectProfile,
      items: [
        for (final item in profiles)
          SoftOsSelectItem(value: item, label: item.realLabel),
      ],
      onChanged: enabled ? onChanged : null,
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
    return SoftOsSelectPill<_MediaCheckFilter>(
      value: value,
      semanticLabel: context.appLocalizations.selectTestItem,
      popupWidth: 240,
      items: [
        for (final item in _MediaCheckFilter.values)
          SoftOsSelectItem(
            value: item,
            label: item.label(context),
            icon: item.icon,
            subtitle: item.subtitle(context),
          ),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _ControlMetricsLine extends StatelessWidget {
  const _ControlMetricsLine({
    required this.targetCount,
    required this.cachedCount,
    required this.concurrency,
    required this.runningCount,
  });

  final int targetCount;
  final int cachedCount;
  final int concurrency;
  final int runningCount;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final items = [
      (context.appLocalizations.nodes, '$targetCount'),
      (context.appLocalizations.cache, '$cachedCount'),
      (context.appLocalizations.concurrency, '$concurrency'),
      if (runningCount > 0) (context.appLocalizations.running, '$runningCount'),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            child: _ControlMetricText(label: items[i].$1, value: items[i].$2),
          ),
          if (i != items.length - 1)
            SizedBox(
              height: 28,
              child: VerticalDivider(
                width: 18,
                thickness: 1,
                color: surge.separator,
              ),
            ),
        ],
      ],
    );
  }
}

class _ControlMetricText extends StatelessWidget {
  const _ControlMetricText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.mediaControlMetricLabel.copyWith(
            color: surge.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.typography.cardTitle.copyWith(
            color: surge.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _MediaCheckInlineStats extends StatelessWidget {
  const _MediaCheckInlineStats({
    required this.filter,
    required this.summary,
    required this.onChanged,
  });

  final _MediaCheckFilter filter;
  final _MediaCheckSummary summary;
  final ValueChanged<_MediaCheckFilter>? onChanged;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Row(
      children: [
        for (var i = 0; i < _MediaCheckFilter.values.length; i++) ...[
          Expanded(
            child: _InlineFilterMetric(
              filter: _MediaCheckFilter.values[i],
              selected: filter == _MediaCheckFilter.values[i],
              value: summary.valueFor(_MediaCheckFilter.values[i]),
              subtitle: summary.subtitleFor(
                context,
                _MediaCheckFilter.values[i],
              ),
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(_MediaCheckFilter.values[i]),
            ),
          ),
          if (i != _MediaCheckFilter.values.length - 1)
            SizedBox(
              height: 46,
              child: VerticalDivider(
                width: 18,
                thickness: 1,
                color: surge.separator,
              ),
            ),
        ],
      ],
    );
  }
}

class _InlineFilterMetric extends StatelessWidget {
  const _InlineFilterMetric({
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
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = filter.color(surge);
    final textColor = selected ? color : surge.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(surge.radii.input),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(filter.icon, size: 14, color: color),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      filter.label(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.typography.mediaFilterTitle.copyWith(
                        color: textColor,
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
                      style: context.typography.mediaFilterSubtitle.copyWith(
                        color: selected
                            ? color.withValues(alpha: 0.82)
                            : surge.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: context.typography.metric.copyWith(color: color),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        ? context.appLocalizations.noCache
        : context.appLocalizations.lastCheckedAt(
            _formatCacheTime(lastCachedAt!),
          );
    return SurgeCard(
      shadow: false,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 1, 10, 1),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    filter.subtitle(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.cardTitle.copyWith(
                      color: surge.textPrimary,
                    ),
                  ),
                ),
                SoftOsIconButton(
                  icon: SurgeIcons.delete,
                  onPressed: cached ? onClear : null,
                  visualSize: 30,
                  tapSize: 40,
                  iconSize: 15,
                ),
                const SizedBox(width: 4),
                Text(
                  cacheText,
                  style: context.typography.supporting.copyWith(
                    color: surge.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: surge.separator),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: _resultPanelMaxHeight),
            child: Theme(
              data: Theme.of(context).copyWith(
                scrollbarTheme: const ScrollbarThemeData(
                  mainAxisMargin: 8,
                  crossAxisMargin: -8,
                ),
              ),
              child: Scrollbar(
                thumbVisibility: false,
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color: surge.separator.withValues(alpha: 0.7),
                  ),
                  itemBuilder: (_, index) =>
                      _MediaCheckResultCard(row: rows[index], filter: filter),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                  style: context.typography.rowTitle.copyWith(
                    color: surge.textPrimary,
                  ),
                ),
              ),
              if (row.target.profile.realLabel.isNotEmpty) ...[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 136),
                  child: Text(
                    row.target.profile.realLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: context.typography.chartLabel.copyWith(
                      color: surge.textSecondary,
                    ),
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
                    context.appLocalizations.expired,
                    style: context.typography.badgeLabel.copyWith(
                      color: surge.orange,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (row.running && result == null)
            _PendingResultLine(filter: filter)
          else if (result != null)
            switch (filter) {
              _MediaCheckFilter.chatGPT => _SingleResultLine(
                color: result.chatGPT.statusColor(surge),
                label: result.chatGPT.localizedChatGPTCompactLabel(
                  context.appLocalizations,
                ),
                meta: result.regionText,
                icon: SurgeIcons.gpt,
              ),
              _MediaCheckFilter.youTubeCN => _SingleResultLine(
                color: result.youTube.youtubeColor(surge),
                label: result.youTube.localizedYoutubeCompactLabel(
                  context.appLocalizations,
                ),
                meta: result.youTube.evidence,
                icon: SurgeIcons.youtube,
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
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(surge.radii.metric),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.mediaResultTitle.copyWith(color: color),
            ),
          ),
          if (meta.isNotEmpty)
            Text(
              meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: context.typography.chartLabel.copyWith(
                color: surge.textSecondary,
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
        borderRadius: BorderRadius.circular(surge.radii.metric),
      ),
      child: Row(
        children: [
          Icon(SurgeIcons.health, color: color, size: SurgeIconSize.inline),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    result.https.compactLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.mediaResultTitle.copyWith(
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  health.localizedLabel(context.appLocalizations),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: context.typography.badgeLabel.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingResultLine extends StatelessWidget {
  const _PendingResultLine({required this.filter});

  final _MediaCheckFilter filter;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    final color = filter.color(surge);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: surge.fill,
        borderRadius: BorderRadius.circular(surge.radii.metric),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.appLocalizations.checking,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.typography.controlLabel.copyWith(
                color: surge.textSecondary,
              ),
            ),
          ),
          Text(
            filter.label(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: context.typography.badgeLabel.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _MediaCheckEmptyResultCard extends StatelessWidget {
  const _MediaCheckEmptyResultCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return SurgeCard(
      shadow: false,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
            child: Text(
              title,
              style: context.typography.cardTitle.copyWith(
                color: surge.textPrimary,
              ),
            ),
          ),
          Divider(height: 1, color: surge.separator),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: context.typography.supporting.copyWith(
                color: surge.textSecondary,
              ),
            ),
          ),
        ],
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
    return SurgeStatusButton(
      key: const Key('media-check-run-button'),
      isActive: checking,
      activeLabel: context.appLocalizations.stop,
      inactiveLabel: context.appLocalizations.start,
      activeColor: surge.red,
      inactiveColor: surge.primary,
      compact: true,
      height: 28,
      horizontalPadding: 3,
      minWidth: 48,
      scaleMetrics: false,
      textStyle: context.typography.mediaRunButtonLabel,
      onPressed: onTap,
    );
  }
}

enum _MediaCheckFilter {
  chatGPT(SurgeIcons.gpt),
  youTubeCN(SurgeIcons.youtube),
  green(SurgeIcons.health);

  final IconData icon;

  const _MediaCheckFilter(this.icon);

  String label(BuildContext context) => switch (this) {
    _MediaCheckFilter.chatGPT => 'GPT',
    _MediaCheckFilter.youTubeCN => 'YouTube',
    _MediaCheckFilter.green => context.appLocalizations.health,
  };

  String resultTitle(BuildContext context) => switch (this) {
    _MediaCheckFilter.chatGPT => context.appLocalizations.gptUnlock,
    _MediaCheckFilter.youTubeCN =>
      context.appLocalizations.youtubeRoutedToChina,
    _MediaCheckFilter.green => context.appLocalizations.allGreenLowLatency,
  };

  String subtitle(BuildContext context) => switch (this) {
    _MediaCheckFilter.chatGPT => context.appLocalizations.unlockedRegions,
    _MediaCheckFilter.youTubeCN =>
      context.appLocalizations.chinaRouteCandidates,
    _MediaCheckFilter.green => context.appLocalizations.historicallyStable,
  };

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

  /// Primary grouping only — within-group order is handled by the sort tiebreaker.
  int rankScore(_MediaCheckFilter filter) {
    final r = result;
    if (r == null) return -1;
    return switch (filter) {
      _MediaCheckFilter.chatGPT => r.chatGPT.isChatGPTAvailable ? 200000 : -1,
      _MediaCheckFilter.youTubeCN =>
        r.youTube.isYouTubeCN
            ? 400000
            : r.youTube.status == 'available'
            ? 300000
            : r.youTube.status == 'unknown'
            ? 200000
            : -1,
      _MediaCheckFilter.green =>
        health.isStableLowLatency
            ? 200000 -
                  (health.medianDelay > 0 ? health.medianDelay : 999999).clamp(
                    0,
                    199999,
                  )
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

  String subtitleFor(BuildContext context, _MediaCheckFilter filter) =>
      filter.subtitle(context);
}
