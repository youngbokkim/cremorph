import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../data/models/reference_photo.dart';
import '../../data/morph_catalog.dart';
import '../../data/reference_photo_repository.dart';
import '../../state/providers.dart';
import '../widgets/common.dart';
import 'photo_picker.dart';

/// Lets a user contribute a reference photo to the shared library.
///
/// Replaces the old flow that asked every contributor to paste a GitHub personal
/// access token: the photo now goes to Supabase Storage under an anonymous
/// session, and row level security is what allows deleting it later.
class ReferencePhotoForm extends ConsumerStatefulWidget {
  const ReferencePhotoForm({super.key});

  @override
  ConsumerState<ReferencePhotoForm> createState() => _ReferencePhotoFormState();
}

class _ReferencePhotoFormState extends ConsumerState<ReferencePhotoForm> {
  final _nameController = TextEditingController();
  final _previewKey = GlobalKey();
  Uint8List? _bytes;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _bytes != null && _nameController.text.trim().isNotEmpty && !_busy;

  Future<void> _pick(ImageSource source) async {
    final bytes = await pickImageBytes(source: source);
    if (bytes == null || !mounted) return;
    setState(() => _bytes = bytes);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final preview = _previewKey.currentContext;
      if (preview != null && preview.mounted) {
        Scrollable.ensureVisible(
          preview,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: 0.15,
        );
      }
    });
  }

  Future<void> _submit() async {
    final bytes = _bytes;
    if (bytes == null) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final photo = await ref
          .read(catalogProvider.notifier)
          .addPhoto(displayName: _nameController.text, originalBytes: bytes);
      if (!mounted) return;
      final linked = matchMorphByName(photo.displayName);
      setState(() {
        _busy = false;
        _bytes = null;
        _message = linked == null
            ? '「${photo.displayName}」(으)로 도감에 새로 추가했습니다.'
            : '「${linked.nameKo}」의 참고 사진으로 추가했습니다.';
        _messageIsError = false;
        _nameController.clear();
      });
    } on ReferencePhotoException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error.message;
        _messageIsError = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = '올리지 못했습니다: $error';
        _messageIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(isOnlineProvider);
    final offlineReason = ref.watch(supabaseServiceProvider).unavailableReason;
    final catalog = ref.watch(catalogProvider);
    final sharedPhotos =
        catalog.value?.sharedPhotos ?? const <ReferencePhoto>[];

    return SectionCard(
      title: '참고 사진 추가',
      subtitle: online
          ? '도감 이미지가 부족할 때 실제 개체 사진과 모프 이름을 올리면 모든 사용자의 분석에 쓰입니다. '
                '기존 모프 이름이면 그 모프의 추가 예시로 붙습니다.'
          : '서버에 연결되어 있지 않아 사진 공유는 사용할 수 없습니다.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!online)
            Callout(
              title: '오프라인 모드',
              text:
                  offlineReason ??
                  'SUPABASE_URL과 SUPABASE_ANON_KEY를 지정해 빌드하면 참고 사진 공유가 켜집니다.',
            )
          else ...[
            _FormBody(
              previewKey: _previewKey,
              bytes: _bytes,
              nameController: _nameController,
              busy: _busy,
              canSubmit: _canSubmit,
              onPickGallery: () => _pick(ImageSource.gallery),
              onPickCamera: supportsCamera
                  ? () => _pick(ImageSource.camera)
                  : null,
              onClear: _bytes == null
                  ? null
                  : () => setState(() => _bytes = null),
              onNameChanged: () => setState(() {}),
              onNamePicked: (name) {
                _nameController.text = name;
                _nameController.selection = TextSelection.collapsed(
                  offset: name.length,
                );
                setState(() {});
              },
              onSubmit: _submit,
            ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _message!,
                  style: AppText.sub.copyWith(
                    color: _messageIsError ? AppColors.danger : AppColors.ok,
                  ),
                ),
              ),
            if (sharedPhotos.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                '공유된 참고 사진 ${sharedPhotos.length}장',
                style: AppText.cardTitle.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                '다른 사용자가 올린 사진도 모두 보이며, 모프 식별과 도감에 같이 쓰입니다.',
                style: AppText.sub,
              ),
              const SizedBox(height: 8),
              for (final photo in sharedPhotos)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SharedPhotoRow(photo: photo),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.previewKey,
    required this.bytes,
    required this.nameController,
    required this.busy,
    required this.canSubmit,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onClear,
    required this.onNameChanged,
    required this.onNamePicked,
    required this.onSubmit,
  });

  final Key previewKey;
  final Uint8List? bytes;
  final TextEditingController nameController;
  final bool busy;
  final bool canSubmit;
  final VoidCallback onPickGallery;
  final VoidCallback? onPickCamera;
  final VoidCallback? onClear;
  final VoidCallback onNameChanged;
  final ValueChanged<String> onNamePicked;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final picker = PhotoDropTarget(
      key: previewKey,
      imageBytes: bytes,
      title: '참고로 쓸 사진',
      hint: '모프가 잘 보이게 찍힌 컷',
      minHeight: 180,
      onTap: onPickGallery,
      onClear: onClear,
    );

    final fields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('모프 이름', style: AppText.sub.copyWith(height: 1.2)),
        const SizedBox(height: 6),
        AppTextField(
          controller: nameController,
          hint: '예: 릴리 화이트, 할로윈, 내가 키우는 할리퀸',
          onChanged: (_) => onNameChanged(),
          onSubmitted: (_) => canSubmit ? onSubmit() : null,
        ),
        _MorphTypeHint(query: nameController.text, onPicked: onNamePicked),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: GhostButton(
                label: '사진 고르기',
                icon: Icons.photo_library_outlined,
                onPressed: onPickGallery,
              ),
            ),
            if (onPickCamera != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: GhostButton(
                  label: '촬영',
                  icon: Icons.photo_camera_outlined,
                  onPressed: onPickCamera,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        AppButton(
          label: matchMorphByName(nameController.text) == null
              ? '도감에 추가하고 분석에 포함'
              : '유사 이미지로 추가하고 분석에 포함',
          busy: busy,
          onPressed: canSubmit ? onSubmit : null,
        ),
      ],
    );

    if (isCompact(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [picker, const SizedBox(height: 16), fields],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 240, child: picker),
        const SizedBox(width: 18),
        Expanded(child: fields),
      ],
    );
  }
}

/// Shows which catalog morph the typed name will attach to, plus other close
/// matches the user can tap to lock in the official type name.
class _MorphTypeHint extends StatelessWidget {
  const _MorphTypeHint({required this.query, required this.onPicked});

  final String query;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) {
    final linked = matchMorphByName(query);
    final suggestions = suggestCatalogMorphs(
      query,
    ).where((m) => m.id != linked?.id).toList();
    if (linked == null && suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (linked != null)
            Text(
              '「${linked.nameKo}」유사 이미지로 도감에 붙고, 모프 식별에도 쓰입니다.',
              style: AppText.sub.copyWith(color: AppColors.ok),
            ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final morph in suggestions)
                  _SuggestionChip(
                    label: morph.nameKo,
                    onTap: () => onPicked(morph.nameKo),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.amber.withValues(alpha: 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.chip),
        side: BorderSide(color: AppColors.amber.withValues(alpha: 0.45)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            label,
            style: AppText.bodySmall.copyWith(
              fontSize: 12.5,
              color: AppColors.amber,
            ),
          ),
        ),
      ),
    );
  }
}

class _SharedPhotoRow extends ConsumerWidget {
  const _SharedPhotoRow({required this.photo});

  final ReferencePhoto photo;

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.modalCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
          side: const BorderSide(color: AppColors.line),
        ),
        title: Text('사진을 삭제할까요?', style: AppText.cardTitle),
        content: Text(
          '「${photo.displayName}」참고 사진이 도감과 분석에서 함께 제거됩니다.',
          style: AppText.sub,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              '취소',
              style: AppText.bodySmall.copyWith(color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              '삭제',
              style: AppText.bodySmall.copyWith(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(catalogProvider.notifier).deletePhoto(photo);
    } on ReferencePhotoException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  String _photoMeta(ReferencePhoto photo) {
    final linked = matchMorphByName(photo.displayName);
    final type = linked == null ? '새 모프' : '${linked.nameKo} 유사 이미지';
    final owner = photo.isMine ? '내가 올림' : '다른 사용자';
    final clip = photo.hasEmbedding ? 'CLIP 완료' : 'CLIP 대기';
    return '$type · $owner · $clip';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.thumb),
            child: SizedBox(
              width: 72,
              height: 56,
              child: MorphImage.path(photo.imageUrl),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photo.displayName,
                  style: AppText.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  _photoMeta(photo),
                  style: AppText.sub.copyWith(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (photo.isMine) ...[
            const SizedBox(width: 8),
            GhostButton(
              label: '삭제',
              dense: true,
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}

/// The `.field input` text box.
class AppTextField extends StatelessWidget {
  const AppTextField({
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      style: AppText.body,
      cursorColor: AppColors.amber,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.sub.copyWith(fontSize: 13.5),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.28),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: _border(AppColors.line),
        enabledBorder: _border(AppColors.line),
        focusedBorder: _border(AppColors.amber.withValues(alpha: 0.6)),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.button),
    borderSide: BorderSide(color: color),
  );
}
