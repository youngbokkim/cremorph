import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/breeding.dart';
import '../../domain/genetics.dart';
import '../widgets/common.dart';

/// Renders a [BreedingResult]: warnings, Mendelian outcomes, then the
/// approximate polygenic pattern forecast.
class BreedResultView extends StatelessWidget {
  const BreedResultView({required this.result, this.dense = false, super.key});

  final BreedingResult result;

  /// Tighter spacing for use inside a chat bubble.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final warning in result.warnings)
          Callout(
            title: warning.title,
            text: warning.text,
            isDanger: warning.level == WarningLevel.danger,
          ),
        if (!dense) ...[
          Text(
            '${result.parentA} × ${result.parentB}',
            style: AppText.cardTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 10),
        ],
        _OutcomeGroup(label: '확정 유전자 (멘델 비율)', outcomes: result.geneOutcomes),
        if (result.patternOutcomes.isNotEmpty) ...[
          const SizedBox(height: 14),
          _OutcomeGroup(
            label: '패턴 예측 (다지성 · 대략치)',
            outcomes: result.patternOutcomes,
            approximate: true,
          ),
        ],
      ],
    );
  }
}

class _OutcomeGroup extends StatelessWidget {
  const _OutcomeGroup({
    required this.label,
    required this.outcomes,
    this.approximate = false,
  });

  final String label;
  final List<OffspringOutcome> outcomes;
  final bool approximate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Kicker(label),
            if (approximate)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.help_outline,
                  size: 13,
                  color: AppColors.muted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final outcome in outcomes)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OutcomeCard(outcome: outcome),
          ),
      ],
    );
  }
}

/// One `.off-card`: photo, phenotype name, note, percentage.
class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.outcome});

  final OffspringOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final borderColor = outcome.lethal
        ? AppColors.danger.withValues(alpha: 0.45)
        : outcome.caution
        ? AppColors.amber.withValues(alpha: 0.4)
        : AppColors.line;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              height: 72,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MorphImage.path(outcome.imagePath),
                  if (outcome.lethal)
                    ColoredBox(
                      color: AppColors.danger.withValues(alpha: 0.28),
                      child: const Center(
                        child: Icon(
                          Icons.dangerous_outlined,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outcome.name,
                      style: AppText.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: outcome.lethal
                            ? const Color(0xFFFFC4BC)
                            : AppColors.cream,
                      ),
                    ),
                    if (outcome.detail.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        outcome.detail,
                        style: AppText.sub.copyWith(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14, left: 4),
              child: Text(
                '${formatPercent(outcome.percent)}%',
                style: AppText.percent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
