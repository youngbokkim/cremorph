import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';

/// Camera capture is not offered on web, where `ImageSource.camera` falls back
/// to a file dialog and just confuses the two buttons.
bool get supportsCamera => !kIsWeb;

final _picker = ImagePicker();

/// Picks an image and returns its bytes, or null when the user cancels.
///
/// Bytes rather than a `File` because web has no file system path, and the
/// analysis pipeline works on bytes on every platform.
Future<Uint8List?> pickImageBytes({
  ImageSource source = ImageSource.gallery,
}) async {
  final file = await _picker.pickImage(
    source: source,
    // Generous cap: the analyser downsamples to 160px anyway, and uploads are
    // re-encoded to 720px separately.
    maxWidth: 2048,
    maxHeight: 2048,
    imageQuality: 92,
  );
  return file?.readAsBytes();
}

/// The `.drop` dashed upload area, including its filled `has-img` state.
class PhotoDropTarget extends StatelessWidget {
  const PhotoDropTarget({
    required this.title,
    required this.hint,
    required this.onTap,
    this.imageBytes,
    this.onBytes,
    this.onClear,
    this.minHeight = 280,
    super.key,
  });

  final Uint8List? imageBytes;
  final String title;
  final String hint;
  final VoidCallback onTap;

  /// Called when a file is dropped onto the target.
  final ValueChanged<Uint8List>? onBytes;

  final VoidCallback? onClear;
  final double minHeight;

  bool get _hasImage => imageBytes != null;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.drop),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.drop),
          border: Border.all(
            color: _hasImage
                ? AppColors.amber.withValues(alpha: 0.4)
                : AppColors.cream.withValues(alpha: 0.28),
            width: 1.5,
          ),
          gradient: RadialGradient(
            center: const Alignment(0, 1.4),
            radius: 1.2,
            colors: [
              AppColors.ember.withValues(alpha: 0.18),
              Colors.black.withValues(alpha: 0.18),
            ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: double.infinity,
              height: minHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_hasImage)
                    Image.memory(
                      imageBytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const _BrokenPreview(),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 28,
                            color: AppColors.muted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: AppText.body.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hint,
                            textAlign: TextAlign.center,
                            style: AppText.sub,
                          ),
                        ],
                      ),
                    ),
                  if (_hasImage && onClear != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _ClearButton(onTap: onClear!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrokenPreview extends StatelessWidget {
  const _BrokenPreview();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.bark,
      child: Center(child: Text('미리보기를 표시하지 못했습니다.', style: AppText.sub)),
    );
  }
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

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
          padding: EdgeInsets.all(6),
          child: Icon(Icons.close, size: 18, color: AppColors.cream),
        ),
      ),
    );
  }
}
