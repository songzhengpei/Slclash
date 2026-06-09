import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter/material.dart';

class ProxiesEmptyState extends StatelessWidget {
  const ProxiesEmptyState({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final surge = SurgeTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.route_rounded,
              color: surge.textSecondary.withValues(alpha: 0.62),
              size: 28,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: surge.textSecondary,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
