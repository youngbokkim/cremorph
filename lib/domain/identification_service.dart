import 'package:flutter/foundation.dart';

import '../data/models/image_features.dart';
import '../data/models/morph.dart';
import '../data/reference_photo_repository.dart';
import 'image_analysis.dart';
import 'morph_scoring.dart';

/// Progress messages surfaced while a photo is being identified.
typedef IdentificationStatus = void Function(String message);

/// Runs morph identification using the hybrid strategy.
///
/// 1. Analyse the photo on-device. This always succeeds, needs no network, and
///    already produces a ranked list — it is what the original web version fell
///    back to when CLIP failed.
/// 2. If Supabase and the `clip-embed` function are reachable, ask the server
///    for CLIP similarities and re-rank with those weighted at 0.82.
///
/// Step 2 is strictly an upgrade: any failure leaves the step 1 result intact.
class IdentificationService {
  IdentificationService({required this.repository, this.useClip = true});

  final ReferencePhotoRepository repository;

  /// Set false to force the offline path, e.g. for tests or a settings toggle.
  final bool useClip;

  /// Identifies the morph in [imageBytes] against [catalog].
  Future<IdentificationResult> identify({
    required Uint8List imageBytes,
    required List<Morph> catalog,
    IdentificationStatus? onStatus,
  }) async {
    onStatus?.call('체색과 패턴을 읽고 있습니다…');

    // Decoding and the 160×160 pixel sweep are pure CPU work, so keep them off
    // the UI isolate to avoid dropping frames on the analysis button tap.
    final features = await compute(_analyzeInIsolate, imageBytes);
    if (features == null) {
      throw const IdentificationException('이미지를 읽지 못했습니다. 다른 사진으로 시도해 주세요.');
    }

    final colorResult = MorphScoring.identifyByColor(
      features,
      catalog: catalog,
    );

    if (!useClip) return colorResult;

    onStatus?.call('도감·공유 참고 사진과 비교하는 중…');
    final similarities = await repository.fetchClipSimilarities(imageBytes);
    if (similarities == null || similarities.isEmpty) {
      return MorphScoring.identifyByColor(
        features,
        catalog: catalog,
        note: '서버 CLIP 비교를 쓸 수 없어 기기에서 색·패턴만으로 추정했습니다.',
      );
    }

    onStatus?.call('결과를 정리하는 중…');
    return MorphScoring.identifyWithClip(
      features: features,
      catalog: catalog,
      clipSimilarityByMorphId: similarities,
    );
  }

  /// Extracts just the colour signature, for tagging an uploaded reference
  /// photo without running a full identification.
  Future<ImageFeatures?> signatureFor(Uint8List imageBytes) =>
      compute(_analyzeInIsolate, imageBytes);
}

/// Top-level so it can be handed to [compute].
ImageFeatures? _analyzeInIsolate(Uint8List bytes) =>
    ImageAnalysis.fromBytes(bytes);

class IdentificationException implements Exception {
  const IdentificationException(this.message);

  final String message;

  @override
  String toString() => message;
}
