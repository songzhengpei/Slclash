import 'dart:async';

import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

typedef ProxyLabelPlayback = Future<void> Function();

/// Keeps proxy-name motion sparse: one label per page, one finite playback.
class ProxyLabelPlaybackCoordinator {
  Object? _activeOwner;
  VoidCallback? _activeStop;
  var _generation = 0;
  var _initialPlaybackClaimed = false;
  var _pageActive = false;

  @visibleForTesting
  bool get hasActivePlayback => _activeOwner != null;

  void setPageActive(bool active) {
    if (_pageActive == active) return;
    _pageActive = active;
    if (active) {
      _initialPlaybackClaimed = false;
    } else {
      cancelActive();
    }
  }

  void play({
    required Object owner,
    required ProxyLabelPlayback playback,
    required VoidCallback stop,
    bool initial = false,
  }) {
    if (!_pageActive) return;
    if (initial) {
      if (_initialPlaybackClaimed) return;
      _initialPlaybackClaimed = true;
    }
    cancelActive();
    final generation = ++_generation;
    _activeOwner = owner;
    _activeStop = stop;
    unawaited(
      playback().whenComplete(() {
        if (generation != _generation || _activeOwner != owner) return;
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
    this.leading = '',
  });

  final String text;
  final String leading;
  final TextStyle style;
  final ProxyLabelPlaybackCoordinator coordinator;

  /// Changing this token replays the label even when its text is unchanged.
  final Object replayToken;

  @override
  State<ScrollingProxyLabel> createState() => _ScrollingProxyLabelState();
}

class _ScrollingProxyLabelState extends State<ScrollingProxyLabel> {
  static const _startDelay = Duration(milliseconds: 800);
  static const _endPause = Duration(milliseconds: 600);
  static const _minimumTravel = Duration(milliseconds: 900);
  static const _maximumTravel = Duration(seconds: 4);
  static const _pixelsPerSecond = 30.0;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    if (tickerEnabled && _tickerEnabled == false) {
      _needsInitialPlayback = true;
    }
    _tickerEnabled = tickerEnabled;
  }

  @override
  void didUpdateWidget(covariant ScrollingProxyLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coordinator != widget.coordinator) {
      oldWidget.coordinator.release(this);
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final painter = TextPainter(
          text: buildEmojiTextSpan(_displayText, widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: textScaler,
          ellipsis: '…',
        )..layout(maxWidth: constraints.maxWidth);
        final overflowing = painter.didExceedMaxLines;
        _isOverflowing = overflowing;
        if (!overflowing) {
          _needsInitialPlayback = false;
          _needsPriorityPlayback = false;
        } else if (_needsPriorityPlayback) {
          _needsPriorityPlayback = false;
          _needsInitialPlayback = false;
          _schedulePlayback(initial: false);
        } else if (_needsInitialPlayback) {
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

        return Semantics(
          label: _displayText,
          excludeSemantics: true,
          child: Tooltip(
            key: _tooltipKey,
            message: _displayText,
            triggerMode: TooltipTriggerMode.manual,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onLongPress: overflowing ? _handleLongPress : null,
              child: RepaintBoundary(child: label),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _disposing = true;
    widget.coordinator.release(this);
    _playbackGeneration++;
    _scrollController.dispose();
    super.dispose();
  }
}
