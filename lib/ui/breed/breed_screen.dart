import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models/breeding.dart';
import '../../data/models/morph.dart';
import '../../data/morph_catalog.dart';
import '../../state/providers.dart';
import '../app_shell.dart';
import '../widgets/common.dart';
import 'breed_chat.dart';
import 'breed_result_view.dart';

class BreedScreen extends ConsumerWidget {
  const BreedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      children: [
        Text(
          '확정 유전자(릴리, 아잔틱, 카푸치노, 팬텀)는 멘델 비율로 정확히 계산하고, '
          '할리퀸·핀·달마 같은 패턴은 다지성이라 대략치로 보여 줍니다.',
          style: AppText.heroNote,
        ),
        const SizedBox(height: AppSpacing.gutter),
        const ResponsiveTwoColumn(
          left: _ParentPicker(),
          right: BreedChatCard(),
        ),
        const AppFooter(),
      ],
    );
  }
}

class _ParentPicker extends ConsumerStatefulWidget {
  const _ParentPicker();

  @override
  ConsumerState<_ParentPicker> createState() => _ParentPickerState();
}

class _ParentPickerState extends ConsumerState<_ParentPicker> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Morph> get _parentMorphs => [
    for (final morph in selectableMorphs)
      if (morph.id != 'soft-scale') morph,
  ];

  List<Morph> get _filteredMorphs {
    final query = normalizeName(_searchController.text);
    if (query.isEmpty) return _parentMorphs;
    return [
      for (final morph in _parentMorphs)
        if (_matchesQuery(morph, query)) morph,
    ];
  }

  bool _matchesQuery(Morph morph, String query) {
    if (normalizeName(morph.nameKo).contains(query)) return true;
    if (normalizeName(morph.nameEn).contains(query)) return true;
    return morph.aliases.any((alias) => normalizeName(alias).contains(query));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(breedProvider);
    final notifier = ref.read(breedProvider.notifier);
    final stacked = isCompact(context);
    final morphs = _filteredMorphs;

    final parentA = _ParentColumn(
      title: '암컷',
      morphId: state.parentAId,
      het: state.hetA,
      morphs: morphs,
      onMorphChanged: notifier.setParentA,
      onHetChanged: notifier.setHetA,
    );

    final parentB = _ParentColumn(
      title: '수컷',
      morphId: state.parentBId,
      het: state.hetB,
      morphs: morphs,
      onMorphChanged: notifier.setParentB,
      onHetChanged: notifier.setHetB,
    );

    return SectionCard(
      title: '부모 모프 고르기',
      subtitle: '두 부모의 모프와 추가 헷을 고르면 자손 표현형 확률을 계산합니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MorphSearchField(
            controller: _searchController,
            matchCount: morphs.length,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (stacked)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [parentA, const SizedBox(height: 14), parentB],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: parentA),
                Padding(
                  padding: const EdgeInsets.only(top: 34, left: 10, right: 10),
                  child: Text(
                    '×',
                    style: AppText.price.copyWith(color: AppColors.amber),
                  ),
                ),
                Expanded(child: parentB),
              ],
            ),
          const SizedBox(height: 16),
          AppButton(
            label: '자손 모프 예측',
            icon: Icons.calculate_outlined,
            onPressed: notifier.predict,
          ),
          if (state.result != null) ...[
            const SizedBox(height: 18),
            BreedResultView(result: state.result!),
          ],
        ],
      ),
    );
  }
}

class _MorphSearchField extends StatelessWidget {
  const _MorphSearchField({
    required this.controller,
    required this.matchCount,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int matchCount;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final hasQuery = controller.text.trim().isNotEmpty;
    return TextField(
      key: const Key('breed-parent-search'),
      controller: controller,
      onChanged: (_) => onChanged(),
      textInputAction: TextInputAction.search,
      style: AppText.body,
      cursorColor: AppColors.amber,
      decoration: InputDecoration(
        hintText: '모프 이름 검색',
        hintStyle: AppText.sub.copyWith(fontSize: 13.5),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.28),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.muted),
        suffixIconConstraints: const BoxConstraints(minHeight: 48),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$matchCount종', style: AppText.sub.copyWith(fontSize: 12)),
            if (hasQuery)
              IconButton(
                tooltip: '검색 지우기',
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
                icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
        border: _border(AppColors.line),
        enabledBorder: _border(AppColors.line),
        focusedBorder: _border(AppColors.amber.withValues(alpha: 0.6)),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: color),
  );
}

class _ParentColumn extends StatelessWidget {
  const _ParentColumn({
    required this.title,
    required this.morphId,
    required this.het,
    required this.morphs,
    required this.onMorphChanged,
    required this.onHetChanged,
  });

  final String title;
  final String morphId;
  final String? het;
  final List<Morph> morphs;
  final ValueChanged<String> onMorphChanged;
  final ValueChanged<String?> onHetChanged;

  @override
  Widget build(BuildContext context) {
    final selected = getMorph(morphId);
    final items = [
      if (selected != null && !morphs.any((m) => m.id == morphId)) selected,
      ...morphs,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: AppText.bodySmall.copyWith(
            color: AppColors.lichen,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        AppDropdown<String>(
          value: morphId,
          items: [
            for (final morph in items)
              DropdownMenuItem(value: morph.id, child: Text(morph.nameKo)),
          ],
          onChanged: (value) {
            if (value != null) onMorphChanged(value);
          },
        ),
        const SizedBox(height: 8),
        AppDropdown<String?>(
          value: het,
          items: [
            const DropdownMenuItem(value: null, child: Text('추가 헷 없음')),
            for (final option in hetOptions)
              DropdownMenuItem(
                value: option.genes.keys.first,
                child: Text('+ ${option.nameKo}'),
              ),
          ],
          onChanged: onHetChanged,
        ),
      ],
    );
  }
}

/// Styled to match the web version's `select` rule.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: AppColors.modalCard,
          borderRadius: BorderRadius.circular(AppRadius.button),
          style: AppText.bodySmall,
          icon: const Icon(Icons.expand_more, color: AppColors.muted, size: 20),
          padding: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }
}

/// Label for a gene's het option, used by the chat cards too.
String hetLabel(String geneKey) => geneMeta[geneKey]?.labels[1] ?? geneKey;

/// Shorthand used when describing a parent that carries an extra het.
String describeProfile(BreedingProfile profile) => profile.label;
