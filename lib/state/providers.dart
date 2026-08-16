import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../data/models/breeding.dart';
import '../data/models/morph.dart';
import '../data/models/reference_photo.dart';
import '../data/morph_catalog.dart';
import '../data/reference_photo_repository.dart';
import '../data/supabase_service.dart';
import '../domain/genetics.dart';
import '../domain/identification_service.dart';
import '../domain/image_analysis.dart';
import '../domain/morph_nlp.dart';
import '../domain/morph_scoring.dart';

final supabaseServiceProvider = Provider<SupabaseService>(
  (ref) => SupabaseService.instance,
);

final referencePhotoRepositoryProvider = Provider<ReferencePhotoRepository>(
  (ref) =>
      ReferencePhotoRepository(service: ref.watch(supabaseServiceProvider)),
);

final identificationServiceProvider = Provider<IdentificationService>(
  (ref) => IdentificationService(
    repository: ref.watch(referencePhotoRepositoryProvider),
  ),
);

/// Whether community features are usable at all.
final isOnlineProvider = Provider<bool>(
  (ref) => ref.watch(supabaseServiceProvider).isAvailable,
);

/// The bundled catalog merged with community photos.
///
/// Falls back to the 18 bundled morphs so every screen has something to show
/// even with no network and no Supabase configuration.
final catalogProvider =
    AsyncNotifierProvider<CatalogNotifier, MorphCatalogSnapshot>(
      CatalogNotifier.new,
    );

class CatalogNotifier extends AsyncNotifier<MorphCatalogSnapshot> {
  @override
  Future<MorphCatalogSnapshot> build() =>
      ref.watch(referencePhotoRepositoryProvider).buildCatalog();

  Future<void> refresh() async {
    state = const AsyncValue<MorphCatalogSnapshot>.loading().copyWithPrevious(
      state,
    );
    state = await AsyncValue.guard(
      () => ref.read(referencePhotoRepositoryProvider).buildCatalog(),
    );
  }

  /// Adds a reference photo and refreshes the catalog so the new photo is
  /// immediately visible in the gallery and used by identification.
  Future<ReferencePhoto> addPhoto({
    required String displayName,
    required Uint8List originalBytes,
  }) async {
    final repository = ref.read(referencePhotoRepositoryProvider);

    final upload = ImageAnalysis.encodeForUpload(
      originalBytes,
      maxEdge: AppConfig.uploadMaxEdge,
      quality: AppConfig.uploadJpegQuality,
    );
    if (upload == null) {
      throw const ReferencePhotoException('이미지를 읽지 못했습니다.');
    }

    final signature = await ref
        .read(identificationServiceProvider)
        .signatureFor(upload);
    if (signature == null) {
      throw const ReferencePhotoException('사진을 분석하지 못했습니다.');
    }

    final photo = await repository.addPhoto(
      displayName: displayName,
      imageBytes: upload,
      signature: signature,
    );
    await refresh();
    return photo;
  }

  Future<void> deletePhoto(ReferencePhoto photo) async {
    await ref.read(referencePhotoRepositoryProvider).deletePhoto(photo);
    await refresh();
  }
}

/// Morphs available for display and comparison right now, whatever the network
/// state.
final availableMorphsProvider = Provider<List<Morph>>((ref) {
  final snapshot = ref.watch(catalogProvider);
  return snapshot.value?.morphs ?? selectableMorphs;
});

// ---------------------------------------------------------------------------
// Identification
// ---------------------------------------------------------------------------

/// The photo the user picked, plus where the identification has got to.
class IdentifyState {
  const IdentifyState({
    this.imageBytes,
    this.result,
    this.status,
    this.error,
    this.isAnalyzing = false,
  });

  final Uint8List? imageBytes;
  final IdentificationResult? result;

  /// Latest progress message.
  final String? status;
  final String? error;
  final bool isAnalyzing;

  bool get hasImage => imageBytes != null;

  IdentifyState copyWith({
    Uint8List? imageBytes,
    IdentificationResult? result,
    String? status,
    String? error,
    bool? isAnalyzing,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return IdentifyState(
      imageBytes: imageBytes ?? this.imageBytes,
      result: clearResult ? null : (result ?? this.result),
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
    );
  }
}

final identifyProvider = NotifierProvider<IdentifyNotifier, IdentifyState>(
  IdentifyNotifier.new,
);

class IdentifyNotifier extends Notifier<IdentifyState> {
  @override
  IdentifyState build() => const IdentifyState();

  void setImage(Uint8List bytes) {
    state = IdentifyState(imageBytes: bytes);
  }

  void clear() {
    state = const IdentifyState();
  }

  Future<void> analyze() async {
    final bytes = state.imageBytes;
    if (bytes == null || state.isAnalyzing) return;

    state = state.copyWith(
      isAnalyzing: true,
      clearResult: true,
      clearError: true,
      status: '분석을 시작합니다…',
    );

    try {
      final result = await ref
          .read(identificationServiceProvider)
          .identify(
            imageBytes: bytes,
            catalog: ref.read(availableMorphsProvider),
            onStatus: (message) {
              if (state.isAnalyzing) {
                state = state.copyWith(status: message);
              }
            },
          );
      state = state.copyWith(result: result, isAnalyzing: false, status: null);
    } on IdentificationException catch (error) {
      state = state.copyWith(isAnalyzing: false, error: error.message);
    } catch (error) {
      state = state.copyWith(isAnalyzing: false, error: '분석에 실패했습니다: $error');
    }
  }
}

// ---------------------------------------------------------------------------
// Breeding
// ---------------------------------------------------------------------------

/// Parent selection and the resulting prediction.
class BreedState {
  const BreedState({
    required this.parentAId,
    required this.parentBId,
    this.hetA,
    this.hetB,
    this.result,
  });

  final String parentAId;
  final String parentBId;

  /// Extra het added on top of parent A, or null.
  final String? hetA;
  final String? hetB;

  final BreedingResult? result;

  BreedState copyWith({
    String? parentAId,
    String? parentBId,
    String? hetA,
    String? hetB,
    BreedingResult? result,
    bool clearHetA = false,
    bool clearHetB = false,
  }) {
    return BreedState(
      parentAId: parentAId ?? this.parentAId,
      parentBId: parentBId ?? this.parentBId,
      hetA: clearHetA ? null : (hetA ?? this.hetA),
      hetB: clearHetB ? null : (hetB ?? this.hetB),
      result: result ?? this.result,
    );
  }
}

final breedProvider = NotifierProvider<BreedNotifier, BreedState>(
  BreedNotifier.new,
);

class BreedNotifier extends Notifier<BreedState> {
  @override
  BreedState build() =>
      const BreedState(parentAId: 'lilly-white', parentBId: 'harlequin');

  void setParentA(String id) => state = state.copyWith(parentAId: id);

  void setParentB(String id) => state = state.copyWith(parentBId: id);

  void setHetA(String? gene) => state = gene == null
      ? state.copyWith(clearHetA: true)
      : state.copyWith(hetA: gene);

  void setHetB(String? gene) => state = gene == null
      ? state.copyWith(clearHetB: true)
      : state.copyWith(hetB: gene);

  BreedingProfile get _profileA =>
      profileForMorphId(state.parentAId).withHet(state.hetA);

  BreedingProfile get _profileB =>
      profileForMorphId(state.parentBId).withHet(state.hetB);

  void predict() {
    state = state.copyWith(result: Genetics.breed(_profileA, _profileB));
  }
}

// ---------------------------------------------------------------------------
// Chat
// ---------------------------------------------------------------------------

/// One turn in the breeding chat.
class ChatMessage {
  const ChatMessage.user(this.text) : isUser = true, answer = null;

  const ChatMessage.bot(this.text, {this.answer}) : isUser = false;

  final String text;
  final bool isUser;

  /// Structured payload rendered as cards beneath the bubble.
  final MorphAnswer? answer;
}

final chatProvider = NotifierProvider<ChatNotifier, List<ChatMessage>>(
  ChatNotifier.new,
);

class ChatNotifier extends Notifier<List<ChatMessage>> {
  @override
  List<ChatMessage> build() => const [
    ChatMessage.bot(
      '안녕하세요. 크레스티드게코 모프를 두 개 말해 주시면 자손 확률을 계산해 드립니다. '
      '한 개만 말하면 그 모프를 설명해 드려요.',
    ),
  ];

  void ask(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final answer = MorphNlp.answer(trimmed);
    state = [
      ...state,
      ChatMessage.user(trimmed),
      ChatMessage.bot(_replyText(answer), answer: answer),
    ];
  }

  String _replyText(MorphAnswer answer) => switch (answer.kind) {
    AnswerKind.breed => answer.result!.summary,
    AnswerKind.info => '${answer.morph!.nameKo} — ${answer.morph!.description}',
    AnswerKind.help =>
      answer.message ?? '모프 이름을 두 개 넣어 보세요. 예: 「릴리화이트랑 아잔틱 섞으면?」',
  };

  void reset() => state = build();
}
