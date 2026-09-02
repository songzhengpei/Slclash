import 'dart:async';

import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef ProxyLabelPlayback = Future<void> Function();

class _QueuedPlayback {
  _QueuedPlayback({
    required this.owner,
    required this.playback,
    required this.stop,
    required this.order,
    required this.ownerKey,
    required this.initial,
  });

  final Object owner;
  final ProxyLabelPlayback playback;
  final VoidCallback stop;
  final int order;
  final String? ownerKey;
  final bool initial;
}

/// Keeps proxy-name motion sparse: one label per page, one finite playback.
class ProxyLabelPlaybackCoordinator {
  Object? _activeOwner;
  VoidCallback? _activeStop;
  var _generation = 0;
  var _initialPlaybackClaimed = false;
  var _pageActive = false;
  var _visit = 0;
  String? _pendingReplayOwnerKey;
  var _flushScheduled = false;
  final _queued = <_QueuedPlayback>[];
  final _visitListeners = ObserverList<VoidCallback>();
  final _replayListeners = ObserverList<void Function(String ownerKey)>();

  @visibleForTesting
  bool get hasActivePlayback => _activeOwner != null;

  @visibleForTesting
  int get pageVisit => _visit;

  void addVisitListener(VoidCallback listener) {
    _visitListeners.add(listener);
  }

  void removeVisitListener(VoidCallback listener) {
    _visitListeners.remove(listener);
  }

  void addReplayListener(void Function(String ownerKey) listener) {
    _replayListeners.add(listener);
  }

  void removeReplayListener(void Function(String ownerKey) listener) {
    _replayListeners.remove(listener);
  }

  void setPageActive(bool active) {
    if (_pageActive == active) return;
    _pageActive = active;
    _queued.clear();
    _flushScheduled = false;
    if (active) {
      _initialPlaybackClaimed = false;
      _pendingReplayOwnerKey = null;
      _visit++;
      for (final listener in List<VoidCallback>.of(_visitListeners)) {
        listener();
      }
    } else {
      _pendingReplayOwnerKey = null;
      cancelActive();
    }
  }

  /// Lets a specific header replay after expand/collapse, even if it remounts.
  void requestReplayFor(String ownerKey) {
    _pendingReplayOwnerKey = ownerKey;
    for (final listener in List<void Function(String)>.of(_replayListeners)) {
      listener(ownerKey);
    }
  }

  void play({
    required Object owner,
    required ProxyLabelPlayback playback,
    required VoidCallback stop,
    bool initial = false,
    String? ownerKey,
    int order = 0,
  }) {
    if (!_pageActive) return;
    final queued = _QueuedPlayback(
      owner: owner,
      playback: playback,
      stop: stop,
      order: order,
      ownerKey: ownerKey,
      initial: initial,
    );
    if (initial ||
        (_pendingReplayOwnerKey != null && ownerKey == _pendingReplayOwnerKey)) {
      _queued.add(queued);
      _scheduleFlush();
      return;
    }
    if (initial && _initialPlaybackClaimed) {
      return;
    }
    _start(queued);
  }

  void _scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    scheduleMicrotask(() {
      _flushScheduled = false;
      _flush();
    });
  }

  void _flush() {
    if (!_pageActive || _queued.isEmpty) return;
    _queued.sort((a, b) => a.order.compareTo(b.order));
    final remaining = List<_QueuedPlayback>.of(_queued);
    _queued.clear();

    _QueuedPlayback? chosen;
    if (_pendingReplayOwnerKey != null) {
      for (final request in remaining) {
        if (request.ownerKey == _pendingReplayOwnerKey) {
          chosen = request;
          _pendingReplayOwnerKey = null;
          break;
        }
      }
    }
    if (chosen == null) {
      if (_initialPlaybackClaimed) return;
      for (final request in remaining) {
        if (request.initial) {
          chosen = request;
          _initialPlaybackClaimed = true;
          break;
        }
      }
    }
    if (chosen == null) return;
    _start(chosen);
  }

  void _start(_QueuedPlayback request) {
    cancelActive();
    final generation = ++_generation;
    _activeOwner = request.owner;
    _activeStop = request.stop;
    unawaited(
      request.playback().whenComplete(() {
        if (generation != _generation || _activeOwner != request.owner) {
          return;
        }
        _activeOwner = null;
        _activeStop = null;
      }),
    );
  }

  void release(Object owner) {
    if (_activeOwner != owner) return;
    cancelActive();
  }

  void cancelActive() {
    _generation++;
    final stop = _activeStop;
    _activeOwner = null;
    _activeStop = null;
    stop?.call();
  }

  void dispose() {
    _pageActive = false;
    _queued.clear();
    _visitListeners.clear();
    _replayListeners.clear();
    cancelActive();
  }
}

/// A single-line proxy label that reveals overflow once, then becomes idle.
class ScrollingProxyLabel extends StatefulWidget {
  const ScrollingProxyLabel({
    super.key,
    required this.text,
    required this.style,
    required this.coordinator,
    required this.replayToken,
    this.ownerKey,
    this.order = 0,
    this.leading = '',
    this.enableInternalLongPress = true,
  });

  final String text;
  final String? ownerKey;
  final int order;
  final String leading;
  final TextStyle style;
  final ProxyLabelPlaybackCoordinator coordinator;

  /// Changing this token replays the label even when its text is unchanged.
  final Object replayToken;
  final bool enableInternalLongPress;

  @override
  State<ScrollingProxyLabel> createState() => _ScrollingProxyLabelState();
}

class _ScrollingProxyLabelState extends State<ScrollingProxyLabel> {
  static const _startDelay = Duration(milliseconds: 800);
  static const _endPause = Duration(milliseconds: 600);
  static const _minimumTravel = Duration(milliseconds: 900);
  static const _maximumTravel = Duration(seconds: 4);
  static const _pixelsPerSecond = 30.0;
  static const _edgeFadeWidth = 12.0;

  final _scrollController = ScrollController();
  final _tooltipKey = GlobalKey<TooltipState>();
  var _playbackGeneration = 0;
  var _isPlaying = false;
  var _isOverflowing = false;
  var _needsInitialPlayback = true;
  var _needsPriorityPlayback = false;
  var _disposing = false;
  bool? _tickerEnabled;

  String get _displayText => '${widget.leading}${widget.text}';

  @override
  void initState() {
    super.initState();
    widget.coordinator.addVisitListener(_onPageVisit);
    widget.coordinator.addReplayListener(_onReplayRequested);
  }

  void _onPageVisit() {
    if (!mounted || _disposing) return;
    _stopPlayback();
    _needsInitialPlayback = true;
    _needsPriorityPlayback = false;
    setState(() {});
  }

  void _onReplayRequested(String ownerKey) {
    if (!mounted || _disposing || widget.ownerKey != ownerKey) return;
    _stopPlayback();
    _needsPriorityPlayback = true;
    _needsInitialPlayback = false;
    setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
  }

  @override
  void didUpdateWidget(covariant ScrollingProxyLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator) {
      oldWidget.coordinator.removeVisitListener(_onPageVisit);
      oldWidget.coordinator.removeReplayListener(_onReplayRequested);
      oldWidget.coordinator.release(this);
      widget.coordinator.addVisitListener(_onPageVisit);
      widget.coordinator.addReplayListener(_onReplayRequested);
    }
    if (oldWidget.text != widget.text ||
        oldWidget.leading != widget.leading ||
        oldWidget.replayToken != widget.replayToken ||
        oldWidget.style != widget.style) {
      _stopPlayback();
      _needsPriorityPlayback = true;
    }
  }

  Duration _travelDuration(double extent) {
    final milliseconds = (extent / _pixelsPerSecond * 1000).round();
    return Duration(
      milliseconds: milliseconds.clamp(
        _minimumTravel.inMilliseconds,
        _maximumTravel.inMilliseconds,
      ),
    );
  }

  Future<void> _play() async {
    final generation = ++_playbackGeneration;
    await Future<void>.delayed(_startDelay);
    if (!_canContinue(generation)) return;
    setState(() => _isPlaying = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!_canContinue(generation) || !_scrollController.hasClients) return;
    final extent = _scrollController.position.maxScrollExtent;
    if (extent <= 0) {
      _finishPlayback(generation);
      return;
    }
    final duration = _travelDuration(extent);
    await _scrollController.animateTo(
      extent,
      duration: duration,
      curve: Curves.linear,
    );
    if (!_canContinue(generation)) return;
    await Future<void>.delayed(_endPause);
    if (!_canContinue(generation)) return;
    await _scrollController.animateTo(
      0,
      duration: duration,
      curve: Curves.linear,
    );
    _finishPlayback(generation);
  }

  bool _canContinue(int generation) {
    return mounted &&
        generation == _playbackGeneration &&
        _tickerEnabled == true &&
        !MediaQuery.disableAnimationsOf(context);
  }

  void _finishPlayback(int generation) {
    if (!mounted || generation != _playbackGeneration) return;
    setState(() => _isPlaying = false);
  }

  void _stopPlayback() {
    _playbackGeneration++;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (!_disposing && mounted && _isPlaying) {
      setState(() => _isPlaying = false);
    }
  }

  void _requestPlayback({required bool initial}) {
    if (!_isOverflowing ||
        _tickerEnabled != true ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    widget.coordinator.play(
      owner: this,
      playback: _play,
      stop: _stopPlayback,
      initial: initial,
      ownerKey: widget.ownerKey,
      order: widget.order,
    );
  }

  void _handleLongPress() {
    if (!_isOverflowing) return;
    _tooltipKey.currentState?.ensureTooltipVisible();
    _requestPlayback(initial: false);
  }

  void _schedulePlayback({required bool initial}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _requestPlayback(initial: initial);
    });
  }

  bool _measureOverflow(BoxConstraints constraints) {
    if (!constraints.hasBoundedWidth || constraints.maxWidth <= 0) {
      return false;
    }
    final painter = TextPainter(
      text: buildEmojiTextSpan(_displayText, widget.style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: double.infinity);
    return painter.width > constraints.maxWidth + 0.5;
  }

  Widget _maybeFadeEdges(Widget child) {
    if (!_isPlaying) return child;
    return ShaderMask(
      shaderCallback: (bounds) {
        final fade = bounds.width <= 0
            ? 0.0
            : (_edgeFadeWidth / bounds.width).clamp(0.0, 0.15);
        return LinearGradient(
          colors: const [
            Color(0x00FFFFFF),
            Color(0xFFFFFFFF),
            Color(0xFFFFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0, fade, 1 - fade, 1],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canMeasure =
            constraints.hasBoundedWidth && constraints.maxWidth > 0;
        final overflowing = canMeasure && _measureOverflow(constraints);
        _isOverflowing = overflowing;
        if (canMeasure && !overflowing) {
          _needsInitialPlayback = false;
          _needsPriorityPlayback = false;
        } else if (overflowing && _needsPriorityPlayback) {
          _needsPriorityPlayback = false;
          _needsInitialPlayback = false;
          _schedulePlayback(initial: false);
        } else if (overflowing && _needsInitialPlayback) {
          _needsInitialPlayback = false;
          _schedulePlayback(initial: true);
        }

        final label = _isPlaying
            ? SingleChildScrollView(
                key: const ValueKey('scrolling-proxy-label-active'),
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: EmojiText(
                  _displayText,
                  maxLines: 1,
                  style: widget.style,
                ),
              )
            : EmojiText(
                _displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: widget.style,
              );

        final painted = Semantics(
          label: _displayText,
          excludeSemantics: true,
          child: RepaintBoundary(child: _maybeFadeEdges(label)),
        );

        if (!widget.enableInternalLongPress) {
          return painted;
        }

        return Tooltip(
          key: _tooltipKey,
          message: _displayText,
          preferBelow: false,
          triggerMode: TooltipTriggerMode.manual,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onLongPress: overflowing ? _handleLongPress : null,
            child: painted,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _disposing = true;
    widget.coordinator.removeVisitListener(_onPageVisit);
    widget.coordinator.removeReplayListener(_onReplayRequested);
    widget.coordinator.release(this);
    _playbackGeneration++;
    _scrollController.dispose();
    super.dispose();
  }
}
