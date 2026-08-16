import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/morph.dart';
import '../../data/morph_catalog.dart';
import '../../domain/quality.dart';
import '../widgets/common.dart';

/// Opens the morph detail view — the equivalent of the web version's `.modal`.
///
/// A bottom sheet on phones (thumb-reachable, swipe to dismiss) and a centred
/// dialog on wide layouts, matching how the original modal looked on desktop.
Future<void> showMorphDetail(BuildContext context, Morph morph) {
  if (isCompact(context)) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.modalScrim,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => _DetailCard(
          morph: morph,
          scrollController: controller,
          showGrabber: true,
        ),
      ),
    );
  }

  return showDialog<void>(
    context: context,
    barrierColor: AppColors.modalScrim,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
        child: _DetailCard(morph: morph),
      ),
    ),
  );
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.morph,
    this.scrollController,
    this.showGrabber = false,
  });

  final Morph morph;
  final ScrollController? scrollController;
  final bool showGrabber;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.modalCard,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            if (showGrabber)
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                    height: 280,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MorphImage(morph: morph),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: _CloseButton(
                            onTap: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
                    child: _DetailBody(morph: morph),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.morph});

  final Morph morph;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          morph.nameKo,
          style: AppText.morphName.copyWith(
            fontSize: 28,
            color: AppColors.cream,
          ),
        ),
        Text(morph.nameEn, style: AppText.en),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            AppBadge(morph.category.labelKo),
            AppBadge(morph.inheritanceKo),
            if (!morph.isCustom)
              AppBadge(
                rarityLabel(morph.rarity),
                color: morph.rarity >= 5 ? AppColors.eye : AppColors.ember,
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(morph.description, style: AppText.body.copyWith(height: 1.6)),
        const SizedBox(height: 18),
        _DetailRow(label: '겉모습', value: morph.look),
        if (!morph.isCustom)
          _DetailRow(
            label: '시세',
            value:
                '${formatWonShort(morph.price.min)} ~ '
                '${formatWonShort(morph.price.max)}',
          ),
        if (morph.genes.values.any((v) => v > 0))
          _DetailRow(label: '유전자', value: _describeGenes(morph)),
        if (morph.traits.isNotEmpty)
          _DetailRow(label: '패턴', value: _describeTraits(morph)),
        if (morph.extraImageUrls.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            '공유된 참고 사진 ${morph.extraImageUrls.length}장',
            style: AppText.cardTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final url in morph.extraImageUrls)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 100,
                    height: 76,
                    child: MorphImage.path(url),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  /// Human-readable gene list, e.g. "릴리 화이트 · 비주얼 아잔틱".
  static String _describeGenes(Morph morph) {
    final parts = <String>[];
    for (final key in GeneKey.all) {
      final copies = morph.gene(key);
      if (copies <= 0) continue;
      final meta = geneMeta[key];
      if (meta != null) parts.add(meta.labels[copies.clamp(0, 2)]);
    }
    return parts.join(' · ');
  }

  /// Pattern strengths as percentages, strongest first.
  static String _describeTraits(Morph morph) {
    final entries = morph.traits.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map(
          (e) =>
              '${traitMeta[e.key]?.name ?? e.key} ${(e.value * 100).round()}%',
        )
        .join(' · ');
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: AppText.sub.copyWith(height: 1.5)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: AppText.bodySmall.copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(7),
          child: Icon(Icons.close, size: 20, color: AppColors.cream),
        ),
      ),
    );
  }
}
