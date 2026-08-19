import 'package:flutter/widgets.dart';

/// Result of walking a page Element tree for vertical [Scrollable]s.
///
/// Visit order matches Home's historical `visitChildElements` walk:
/// the page root itself is not counted; only descendants are.
class VerticalScrollVisit {
  const VerticalScrollVisit({
    required this.elementsVisited,
    required this.positions,
    required this.elapsedMicros,
  });

  final int elementsVisited;
  final List<ScrollPosition> positions;
  final int elapsedMicros;

  int get positionCount => positions.length;
}

/// Collect vertical [ScrollPosition]s under [root] without mutating them.
VerticalScrollVisit collectVerticalScrollPositions(Element root) {
  final watch = Stopwatch()..start();
  var elementsVisited = 0;
  final positions = <ScrollPosition>{};

  void collect(Element element) {
    elementsVisited++;
    if (element is StatefulElement && element.state is ScrollableState) {
      final position = (element.state as ScrollableState).position;
      if (position.axis == Axis.vertical &&
          position.hasPixels &&
          position.hasContentDimensions) {
        positions.add(position);
      }
    }
    element.visitChildElements(collect);
  }

  root.visitChildElements(collect);
  watch.stop();
  return VerticalScrollVisit(
    elementsVisited: elementsVisited,
    positions: List<ScrollPosition>.unmodifiable(positions),
    elapsedMicros: watch.elapsedMicroseconds,
  );
}

double scrollToTopTarget(ScrollPosition position) {
  return position.axisDirection == AxisDirection.up
      ? position.maxScrollExtent
      : position.minScrollExtent;
}
