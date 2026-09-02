import 'package:emoji_regex/emoji_regex.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:flutter/material.dart';

import '../state.dart';

/// Long-press shows [message] above the widget without stealing taps.
class LongPressFullText extends StatefulWidget {
  const LongPressFullText({
    super.key,
    required this.message,
    required this.child,
    this.onLongPress,
  });

  final String message;
  final Widget child;
  final VoidCallback? onLongPress;

  @override
  State<LongPressFullText> createState() => _LongPressFullTextState();
}

class _LongPressFullTextState extends State<LongPressFullText> {
  final _tooltipKey = GlobalKey<TooltipState>();

  void _handleLongPress() {
    if (widget.message.isEmpty) return;
    _tooltipKey.currentState?.ensureTooltipVisible();
    widget.onLongPress?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isEmpty) {
      return widget.child;
    }
    return Tooltip(
      key: _tooltipKey,
      message: widget.message,
      preferBelow: false,
      triggerMode: TooltipTriggerMode.manual,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: _handleLongPress,
        child: widget.child,
      ),
    );
  }
}

class TooltipText extends StatelessWidget {
  final Text text;

  const TooltipText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isOverflow = globalState.measure.computeTextIsOverflow(
          text,
          maxWidth: maxWidth,
        );
        if (isOverflow) {
          return Tooltip(
            triggerMode: TooltipTriggerMode.longPress,
            preferBelow: false,
            message: text.data,
            child: text,
          );
        }
        return text;
      },
    );
  }
}

class TooltipTextV2 extends StatefulWidget {
  final Text text;

  const TooltipTextV2({super.key, required this.text});

  @override
  State<TooltipTextV2> createState() => _TooltipTextV2State();
}

class _TooltipTextV2State extends State<TooltipTextV2> {
  bool _isOverflow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOverflow();
    });
  }

  void _checkOverflow() {
    if (!mounted) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final isOverflow = globalState.measure.computeTextIsOverflow(
      widget.text,
      maxWidth: renderBox.size.width,
    );
    setState(() => _isOverflow = isOverflow);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      triggerMode: TooltipTriggerMode.longPress,
      preferBelow: false,
      message: _isOverflow ? widget.text.data : '',
      child: widget.text,
    );
  }
}

class EmojiText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const EmojiText(
    this.text, {
    super.key,
    this.maxLines,
    this.overflow,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      textScaler: MediaQuery.of(context).textScaler,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: buildEmojiTextSpan(text, style),
    );
  }
}

/// Builds the same emoji-aware span tree used by [EmojiText].
///
/// Keeping this public lets constrained text widgets measure and paint the
/// exact same glyphs instead of approximating emoji widths with the body font.
TextSpan buildEmojiTextSpan(String text, TextStyle? style) {
  final spans = <TextSpan>[];
  final matches = emojiRegex().allMatches(text);

  var lastMatchEnd = 0;
  for (final match in matches) {
    if (match.start > lastMatchEnd) {
      spans.add(
        TextSpan(text: text.substring(lastMatchEnd, match.start), style: style),
      );
    }
    spans.add(
      TextSpan(
        text: match.group(0),
        style: style?.copyWith(fontFamily: FontFamily.twEmoji.value),
      ),
    );
    lastMatchEnd = match.end;
  }
  if (lastMatchEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastMatchEnd), style: style));
  }
  return TextSpan(children: spans);
}

// class HighlightText extends StatelessWidget {
//   const HighlightText({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return RichText(
//       textScaler: MediaQuery.of(context).textScaler,
//       maxLines: maxLines,
//       overflow: overflow ?? TextOverflow.clip,
//       text: TextSpan(
//         children: _buildTextSpans(text),
//       ),
//     );
//   }
// }
