import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models/morph.dart';
import '../../data/models/reference_photo.dart';
import '../../data/morph_catalog.dart';
import '../../state/providers.dart';
import '../app_shell.dart';
import '../widgets/common.dart';
import 'morph_detail_sheet.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  /// Null means "all categories".
  MorphCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final all = ref.watch(availableMorphsProvider);
    final morphs = _filter == null
        ? all
        : all.where((m) => m.category == _filter).toList();

    final categories = <MorphCategory>[
      for (final category in MorphCategory.values)
        if (all.any((m) => m.category == category)) category,
    ];

    return RefreshIndicator(
      color: AppColors.amber,
      backgroundColor: AppColors.modalCard,
      onRefresh: ref.read(catalogProvider.notifier).refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
        children: [
          SectionCard(
            title: '모프 도감',
            subtitle:
                '각 모프가 어떻게 보이는지 한눈에 보는 참고 사진입니다. '
                '공유된 참고 사진도 여기에 같이 나옵니다.',
            trailing: catalog.isLoading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChip(
                  label: '전체 ${all.length}',
                  active: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                for (final category in categories)
                  _FilterChip(
                    label: category.labelKo,
                    active: _filter == category,
                    onTap: () => setState(() => _filter = category),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (catalog.value?.sharedPhotos.isNotEmpty == true) ...[
            _SharedPhotoSection(photos: catalog.value!.sharedPhotos),
            const SizedBox(height: 18),
          ],
          _MorphGrid(morphs: morphs),
          const AppFooter(),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppColors.amber.withValues(alpha: 0.18)
          : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        side: BorderSide(
          color: active
              ? AppColors.amber.withValues(alpha: 0.6)
              : AppColors.line,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: AppText.bodySmall.copyWith(
              fontSize: 12.5,
              color: active ? AppColors.amber : AppColors.muted,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// The `.gallery` grid: `repeat(auto-fill, minmax(220px, 1fr))`.
class _MorphGrid extends StatelessWidget {
  const _MorphGrid({required this.morphs});

  final List<Morph> morphs;

  @override
  Widget build(BuildContext context) {
    if (morphs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(child: Text('해당 분류의 모프가 없습니다.', style: AppText.sub)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const minTileWidth = 220.0;
        const gap = 16.0;
        final columns = ((constraints.maxWidth + gap) / (minTileWidth + gap))
            .floor()
            .clamp(1, 5);

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            // 160px image + roughly 120px of text block.
            mainAxisExtent: 292,
          ),
          itemCount: morphs.length,
          itemBuilder: (context, index) => _MorphTile(morph: morphs[index]),
        );
      },
    );
  }
}

/// One `.g-card` tile.
class _MorphTile extends StatelessWidget {
  const _MorphTile({required this.morph});

  final Morph morph;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: morph.isCustom ? AppColors.paperCustom : AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showMorphDetail(context, morph),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MorphImage(morph: morph),
                  if (morph.extraImageUrls.isNotEmpty)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: _PhotoCountBadge(
                        count: morph.extraImageUrls.length,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      morph.nameKo,
                      style: AppText.morphName.copyWith(fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      morph.nameEn,
                      style: AppText.en.copyWith(
                        color: AppColors.ink.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        morph.look,
                        style: AppText.bodySmall.copyWith(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppColors.ink,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoCountBadge extends StatelessWidget {
  const _PhotoCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.collections_outlined,
              size: 12,
              color: AppColors.cream,
            ),
            const SizedBox(width: 4),
            Text(
              '+$count',
              style: AppText.badge.copyWith(color: AppColors.cream),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every community reference photo, including ones uploaded by other people.
class _SharedPhotoSection extends StatelessWidget {
  const _SharedPhotoSection({required this.photos});

  final List<ReferencePhoto> photos;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '공유된 참고 사진 ${photos.length}장',
      subtitle: '다른 사용자가 올린 실물 사진입니다. 모프 식별에도 같이 쓰입니다.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final photo in photos) _SharedPhotoTile(photo: photo)],
      ),
    );
  }
}

class _SharedPhotoTile extends ConsumerWidget {
  const _SharedPhotoTile({required this.photo});

  final ReferencePhoto photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linked = matchMorphByName(photo.displayName);
    final morphId = linked?.id ?? userMorphId(photo.displayName);
    final merged = ref
        .watch(availableMorphsProvider)
        .where((m) => m.id == morphId)
        .firstOrNull;
    return Material(
      color: AppColors.paper,
      borderRadius: BorderRadius.circular(AppRadius.thumb),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: merged == null ? null : () => showMorphDetail(context, merged),
        child: SizedBox(
          width: 108,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 80, child: MorphImage.path(photo.imageUrl)),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photo.displayName,
                      style: AppText.bodySmall.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        if (linked != null) linked.nameKo,
                        if (photo.isMine) '내가 올림' else '다른 사용자',
                      ].join(' · '),
                      style: AppText.sub.copyWith(
                        fontSize: 11,
                        color: AppColors.ink.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
