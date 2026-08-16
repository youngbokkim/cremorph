import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/morph_scoring.dart';
import '../../domain/quality.dart';
import '../gallery/morph_detail_sheet.dart';
import '../widgets/common.dart';

/// Renders an [IdentificationResult]: hero match, alternatives, quality stamp,
/// price band and the reference thumbnails backing the guess.
class IdentifyResultView extends StatelessWidget {
  const IdentifyResultView({required this.result, super.key});

  final IdentificationResult result;

  @override
  Widget build(BuildContext context) {
    final top = result.top;
    if (top == null) {
      return Text('비교할 도감 사진이 없습니다.', style: AppText.sub);
    }

    final quality = QualityGrading.grade(result.features, top.morph);
    final price = QualityGrading.estimate(top.morph, quality);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MethodNote(result: result),
        if (result.lowConfidence)
          const Callout(
            title: '확신도가 낮습니다',
            text: '후보들의 점수 차가 작습니다. 개체가 크게, 밝게 찍힌 사진으로 다시 시도하면 정확도가 올라갑니다.',
          ),
        _HeroMatch(match: top),
        const SizedBox(height: 14),
        if (result.alternatives.isNotEmpty) ...[
          Text('비슷한 후보', style: AppText.cardTitle.copyWith(fontSize: 15)),
          const SizedBox(height: 8),
          for (final alt in result.alternatives)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AlternativeRow(match: alt),
            ),
          const SizedBox(height: 6),
        ],
        _QualityPanel(quality: quality, price: price),
        if (top.morph.extraImageUrls.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            '공유된 참고 사진 ${top.morph.extraImageUrls.length}장',
            style: AppText.cardTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 8),
          _ThumbnailRow(urls: top.morph.extraImageUrls),
        ],
      ],
    );
  }
}

/// Explains which path produced the ranking, so a low score is interpretable.
class _MethodNote extends StatelessWidget {
  const _MethodNote({required this.result});

  final IdentificationResult result;

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (result.source) {
      IdentificationSource.clip => (
        Icons.auto_awesome_outlined,
        'CLIP 딥러닝 임베딩(82%)과 기기의 색·패턴 분석(18%)을 합쳐 계산했습니다.',
      ),
      IdentificationSource.color => (
        Icons.smartphone_outlined,
        result.note ?? '기기에서 색·패턴만으로 추정했습니다.',
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppText.sub.copyWith(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

/// The `.morph-hero` light card on the dark page.
class _HeroMatch extends StatelessWidget {
  const _HeroMatch({required this.match});

  final MorphMatch match;

  @override
  Widget build(BuildContext context) {
    final morph = match.morph;
    final stacked = isCompact(context);

    final meta = Padding(
      padding: EdgeInsets.fromLTRB(stacked ? 16 : 0, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker('확신도 ${match.confidence}%'),
          const SizedBox(height: 4),
          Text(morph.nameKo, style: AppText.morphName),
          Text(
            morph.nameEn,
            style: AppText.en.copyWith(
              color: AppColors.ink.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            morph.look,
            style: AppText.bodySmall.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppBadge(morph.category.labelKo),
              AppBadge(morph.inheritanceKo),
              if (!morph.isCustom) AppBadge(rarityLabel(morph.rarity)),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => showMorphDetail(context, morph),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '자세히 보기',
                  style: AppText.bodySmall.copyWith(
                    color: AppColors.ember,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.ember,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.drop),
      child: ColoredBox(
        color: AppColors.paper,
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 180, child: MorphImage(morph: morph)),
                  meta,
                ],
              )
            // `height: 100%; min-height: 148px` on the image: it fills
            // whatever height the text beside it needs, but never less than the
            // column is wide.
            : ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 148),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: 148, child: MorphImage(morph: morph)),
                      const SizedBox(width: 16),
                      Expanded(child: meta),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// One `.alt` row: thumbnail, name, confidence bar, percentage.
class _AlternativeRow extends StatelessWidget {
  const _AlternativeRow({required this.match});

  final MorphMatch match;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: InkWell(
        onTap: () => showMorphDetail(context, match.morph),
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.thumb),
                child: SizedBox(
                  width: 56,
                  height: 44,
                  child: MorphImage(morph: match.morph),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.morph.nameKo,
                      style: AppText.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    ConfidenceBar(value: match.confidence / 100),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text('${match.confidence}%', style: AppText.percent),
            ],
          ),
        ),
      ),
    );
  }
}

/// The `.quality` panel with its rotated `.stamp` and price band.
class _QualityPanel extends StatelessWidget {
  const _QualityPanel({required this.quality, required this.price});

  final QualityGrade quality;
  final PriceEstimate price;

  Color get _stampColor => switch (quality.rank) {
    QualityRank.s => AppColors.eye,
    QualityRank.a => AppColors.amber,
    QualityRank.b => AppColors.muted,
    QualityRank.c => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.tile),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Transform.rotate(
                angle: -8 * 3.1415926 / 180,
                child: Container(
                  width: 86,
                  height: 86,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _stampColor, width: 3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        quality.rank.name.toUpperCase(),
                        style: AppText.percent.copyWith(
                          color: _stampColor,
                          fontSize: 26,
                        ),
                      ),
                      Text(
                        quality.labelKo,
                        style: AppText.badge.copyWith(color: _stampColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Kicker('예상 시세'),
                    const SizedBox(height: 4),
                    Text(
                      '${formatWonShort(price.min)} ~ ${formatWonShort(price.max)}',
                      style: AppText.price,
                    ),
                    const SizedBox(height: 4),
                    Text('사진 퀄리티 점수 ${quality.score}점', style: AppText.sub),
                  ],
                ),
              ),
            ],
          ),
          if (quality.reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final reason in quality.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('· $reason', style: AppText.sub),
              ),
          ],
          const SizedBox(height: 8),
          Text(price.note, style: AppText.sub.copyWith(fontSize: 11.5)),
        ],
      ),
    );
  }
}

/// The `.thumb-row` strip of community reference photos.
class _ThumbnailRow extends StatelessWidget {
  const _ThumbnailRow({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final url in urls.take(8))
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(width: 88, height: 68, child: MorphImage.path(url)),
          ),
      ],
    );
  }
}
