import 'dart:async';
import 'dart:io';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

final _memoryStateNotifier = ValueNotifier<num>(0);

class MemoryInfo extends StatefulWidget {
  const MemoryInfo({super.key});

  @override
  State<MemoryInfo> createState() => _MemoryInfoState();
}

class _MemoryInfoState extends State<MemoryInfo> {
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _updateMemory();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _updateMemory() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final rss = ProcessInfo.currentRss;
      if (coreController.isCompleted) {
        _memoryStateNotifier.value = await coreController.getMemory() + rss;
      } else {
        _memoryStateNotifier.value = rss;
      }
      timer = Timer(const Duration(seconds: 2), () async {
        _updateMemory();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return SizedBox(
      height: getWidgetHeight(1),
      child: RepaintBoundary(
        child: SurgeActionCard(
          variant: SurgeActionCardVariant.filled,
          borderRadius: SurgeTheme.of(context).radii.card,
          padding: EdgeInsets.all(SurgeTheme.of(context).spacing.cardPadding),
          onTap: () {
            coreController.requestGc();
          },
          child: _MemoryCardContent(title: appLocalizations.memoryInfo),
        ),
      ),
    );
  }
}

class _MemoryCardContent extends StatelessWidget {
  const _MemoryCardContent({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.memory, color: surge.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelLarge?.copyWith(
                  color: surge.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
        ValueListenableBuilder(
          valueListenable: _memoryStateNotifier,
          builder: (_, memory, _) {
            final traffic = memory.traffic;
            return Row(
              children: [
                Text(
                  traffic.value,
                  style: context.textTheme.titleMedium?.copyWith(
                    color: surge.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  traffic.unit,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: surge.textSecondary,
                    fontSize: 13,
                    letterSpacing: 0,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
