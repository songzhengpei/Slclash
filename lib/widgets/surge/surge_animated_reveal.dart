import 'package:flutter/material.dart';

import 'surge_motion.dart';

class SurgeAnimatedReveal extends StatelessWidget {
  const SurgeAnimatedReveal({
    super.key,
    required this.visible,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final bool visible;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: SurgeMotion.container,
      reverseDuration: SurgeMotion.reveal,
      curve: SurgeMotion.stateCurve,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: SurgeMotion.reveal,
        reverseDuration: SurgeMotion.state,
        switchInCurve: SurgeMotion.enterCurve,
        switchOutCurve: SurgeMotion.exitCurve,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: alignment,
          children: [...previousChildren, ?currentChild],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) => Transform.translate(
              offset: Offset(
                0,
                -SurgeMotion.revealOffset * (1 - animation.value),
              ),
              child: child,
            ),
          ),
        ),
        child: visible
            ? KeyedSubtree(key: const ValueKey(true), child: child)
            : const SizedBox(key: ValueKey(false), width: double.infinity),
      ),
    );
  }
}
