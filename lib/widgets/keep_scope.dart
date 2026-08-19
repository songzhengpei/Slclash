import 'package:flutter/material.dart';

class KeepScope extends StatefulWidget {
  final Widget child;
  final bool keep;

  const KeepScope({super.key, required this.child, this.keep = true});

  @override
  State<KeepScope> createState() => _KeepContainerState();
}

class _KeepContainerState extends State<KeepScope>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  void didUpdateWidget(covariant KeepScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keep != widget.keep) {
      updateKeepAlive();
    }
  }

  @override
  bool get wantKeepAlive => widget.keep;
}
