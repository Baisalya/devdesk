import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../models/diff_models.dart';

class DiffHistoryPanel extends ConsumerWidget {
  final List<DiffSession> sessions;
  final Function(DiffSession) onSelect;

  const DiffHistoryPanel({
    super.key,
    required this.sessions,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sessions.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history,
        title: 'No history',
        message: 'Your recent comparisons will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: sessions.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return AppCard(
          onTap: () => onSelect(session),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.title,
                style: Theme.of(context).textTheme.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Text(
                    _formatDate(session.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (session.summary != null) ...[
                    _SummaryBadge(
                      label: '+${session.summary!.added}',
                      color: Colors.green.withValues(alpha: 0.1),
                      textColor: Colors.green,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _SummaryBadge(
                      label: '-${session.summary!.removed}',
                      color: Colors.red.withValues(alpha: 0.1),
                      textColor: Colors.red,
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _SummaryBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _SummaryBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
