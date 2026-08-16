import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../state/providers.dart';
import '../app_shell.dart';
import '../widgets/common.dart';
import 'identify_result_view.dart';
import 'photo_picker.dart';
import 'reference_photo_form.dart';

class IdentifyScreen extends ConsumerWidget {
  const IdentifyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      children: [
        Text(
          '사진을 올리면 도감 사진과 공유된 참고 사진을 함께 비교해 모프를 추정합니다. '
          '두 모프를 물어보면 유전자 확률과 참고 사진을 같이 보여 줍니다.',
          style: AppText.heroNote,
        ),
        const SizedBox(height: AppSpacing.gutter),
        const ResponsiveTwoColumn(left: _UploadCard(), right: _ResultCard()),
        const SizedBox(height: AppSpacing.gutter),
        const ReferencePhotoForm(),
        const AppFooter(),
      ],
    );
  }
}

class _UploadCard extends ConsumerWidget {
  const _UploadCard();

  Future<void> _pick(WidgetRef ref, ImageSource source) async {
    final bytes = await pickImageBytes(source: source);
    if (bytes != null) ref.read(identifyProvider.notifier).setImage(bytes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(identifyProvider);
    final notifier = ref.read(identifyProvider.notifier);

    return SectionCard(
      title: '게코 사진으로 모프 찾기',
      subtitle:
          '기기에서 체색·패턴을 분석하고, 서버가 켜져 있으면 CLIP 딥러닝 비교까지 함께 씁니다. '
          '식별용으로 올린 사진은 기기에만 있고 서버에 올라가지 않습니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PhotoDropTarget(
            imageBytes: state.imageBytes,
            title: '사진을 놓거나 눌러서 업로드',
            hint: 'JPG, PNG · 크레스티드게코 한 마리가 크게 나온 컷',
            onTap: () => _pick(ref, ImageSource.gallery),
            onBytes: notifier.setImage,
            onClear: state.hasImage ? notifier.clear : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GhostButton(
                  label: '갤러리',
                  icon: Icons.photo_library_outlined,
                  onPressed: () => _pick(ref, ImageSource.gallery),
                ),
              ),
              if (supportsCamera) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: GhostButton(
                    label: '카메라',
                    icon: Icons.photo_camera_outlined,
                    onPressed: () => _pick(ref, ImageSource.camera),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          AppButton(
            label: '모프 분석하기',
            busy: state.isAnalyzing,
            onPressed: state.hasImage ? notifier.analyze : null,
          ),
          if (state.isAnalyzing)
            AnalyzingIndicator(message: state.status ?? '분석 중입니다…'),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Callout(
                title: '분석하지 못했습니다',
                text: state.error!,
                isDanger: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends ConsumerWidget {
  const _ResultCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(identifyProvider);

    return SectionCard(
      title: '분석 결과',
      subtitle: '가장 가까운 모프, 비슷한 후보, 참고 실물 사진입니다.',
      child: switch (state) {
        IdentifyState(result: final result?) => IdentifyResultView(
          result: result,
        ),
        IdentifyState(isAnalyzing: true) => const _ResultPlaceholder(
          icon: Icons.hourglass_empty,
          message: '사진을 읽고 도감과 비교하는 중입니다…',
        ),
        IdentifyState(hasImage: true) => const _ResultPlaceholder(
          icon: Icons.touch_app_outlined,
          message: '사진이 준비됐습니다. 「모프 분석하기」를 눌러 주세요.',
        ),
        _ => const _ResultPlaceholder(
          icon: Icons.image_outlined,
          message: '아직 사진이 없습니다. 위에서 업로드해 주세요.',
        ),
      },
    );
  }
}

class _ResultPlaceholder extends StatelessWidget {
  const _ResultPlaceholder({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 30, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(message, style: AppText.sub, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
