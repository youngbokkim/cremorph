import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';
import 'models/image_features.dart';
import 'models/morph.dart';
import 'models/reference_photo.dart';
import 'morph_catalog.dart';
import 'supabase_service.dart';

/// Raised when a community action fails in a way worth showing the user.
class ReferencePhotoException implements Exception {
  const ReferencePhotoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The morph catalog merged with community reference photos.
///
/// Equivalent to `buildCatalog()` in the old `js/library.js`: built-in morphs
/// gain `extraPhotoIds`/`extraImageUrls` for the photos attached to them, and
/// unrecognised names become their own `user-` morph entries.
class MorphCatalogSnapshot {
  const MorphCatalogSnapshot({required this.morphs, required this.photos});

  const MorphCatalogSnapshot.bundledOnly(this.morphs) : photos = const [];

  final List<Morph> morphs;
  final List<ReferencePhoto> photos;

  List<Morph> get communityMorphs =>
      morphs.where((m) => m.isCustom).toList(growable: false);

  /// Photos contributed by the current user, newest first.
  List<ReferencePhoto> get myPhotos =>
      photos.where((p) => p.isMine).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Every shared reference photo, newest first — including other users'.
  List<ReferencePhoto> get sharedPhotos =>
      List<ReferencePhoto>.of(photos)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Morph? byId(String id) =>
      morphs.where((m) => m.id == id).firstOrNull ?? getMorph(id);
}

/// Reads and writes the shared reference photo library.
class ReferencePhotoRepository {
  ReferencePhotoRepository({SupabaseService? service, Uuid? uuid})
    : _service = service ?? SupabaseService.instance,
      _uuid = uuid ?? const Uuid();

  final SupabaseService _service;
  final Uuid _uuid;

  static const _table = 'reference_photos';

  /// Columns worth transferring — `embedding` is excluded on purpose, since a
  /// 512-float vector per row would dwarf everything else.
  static const _columns =
      'id, display_name, morph_id, storage_path, signature, has_embedding, '
      'created_by, created_at';

  SupabaseClient get _client => _service.client;

  String _publicUrl(String storagePath) =>
      _client.storage.from(AppConfig.photoBucket).getPublicUrl(storagePath);

  /// Fetches every shared photo. Returns an empty list when offline rather than
  /// throwing, so the gallery degrades to the bundled catalog.
  Future<List<ReferencePhoto>> fetchPhotos() async {
    if (!_service.isAvailable) return const [];
    try {
      final rows = await _client
          .from(_table)
          .select(_columns)
          .order('created_at', ascending: false);
      final currentUserId = _service.userId;
      return rows
          .map(
            (row) => ReferencePhoto.fromRow(
              row,
              publicUrlBuilder: _publicUrl,
              currentUserId: currentUserId,
            ),
          )
          .toList();
    } catch (error) {
      debugPrint('CREHOONI: fetchPhotos failed — $error');
      return const [];
    }
  }

  /// Builds the merged catalog used by the gallery and the identifier.
  Future<MorphCatalogSnapshot> buildCatalog() async {
    final photos = await fetchPhotos();
    return mergeCatalog(photos);
  }

  /// Pure merge of [photos] into the bundled catalog. Split out from
  /// [buildCatalog] so it can be unit tested without a network.
  @visibleForTesting
  static MorphCatalogSnapshot mergeCatalog(List<ReferencePhoto> photos) {
    final extraIds = <String, List<String>>{};
    final extraUrls = <String, List<String>>{};
    final extraSignatures = <String, List<ImageFeatures>>{};
    final communityOnly = <String, ReferencePhoto>{};

    for (final photo in photos) {
      final linked = matchMorphByName(photo.displayName);
      final id = linked?.id ?? userMorphId(photo.displayName);
      (extraIds[id] ??= []).add(photo.catalogKey);
      (extraUrls[id] ??= []).add(photo.imageUrl);
      if (photo.signature != null) {
        (extraSignatures[id] ??= []).add(photo.signature!);
      }
      if (linked == null) communityOnly.putIfAbsent(id, () => photo);
    }

    final merged = <Morph>[
      for (final morph in selectableMorphs)
        morph.copyWith(
          extraPhotoIds: extraIds[morph.id] ?? const [],
          extraImageUrls: extraUrls[morph.id] ?? const [],
          extraSignatures: extraSignatures[morph.id] ?? const [],
        ),
      for (final entry in communityOnly.entries)
        _communityMorph(
          id: entry.key,
          photo: entry.value,
          extraPhotoIds: extraIds[entry.key] ?? const [],
          extraImageUrls: extraUrls[entry.key] ?? const [],
          extraSignatures: extraSignatures[entry.key] ?? const [],
        ),
    ];

    return MorphCatalogSnapshot(morphs: merged, photos: photos);
  }

  /// Wraps an unrecognised contributed name as its own morph entry.
  /// Ported from `makeUserMorph()` in `js/library.js`.
  static Morph _communityMorph({
    required String id,
    required ReferencePhoto photo,
    required List<String> extraPhotoIds,
    required List<String> extraImageUrls,
    required List<ImageFeatures> extraSignatures,
  }) {
    return Morph(
      id: id,
      nameKo: photo.displayName,
      nameEn: 'Community',
      category: MorphCategory.custom,
      inheritance: Inheritance.unknown,
      inheritanceKo: '공유된 참고 사진',
      description: '다른 사용자가 올린 참고 개체입니다. 모프 분석 때 이 사진과도 비교합니다.',
      look: '공유 참고 사진',
      networkImage: photo.imageUrl,
      aliases: [photo.displayName],
      signature: photo.signature ?? extraSignatures.firstOrNull,
      isCustom: true,
      extraPhotoIds: extraPhotoIds,
      extraImageUrls: extraImageUrls,
      extraSignatures: extraSignatures,
    );
  }

  /// Uploads a photo to shared storage and records it in the library.
  ///
  /// [imageBytes] should already be downscaled — see
  /// `ImageAnalysis.encodeForUpload`.
  Future<ReferencePhoto> addPhoto({
    required String displayName,
    required Uint8List imageBytes,
    required ImageFeatures signature,
  }) async {
    if (!_service.isAvailable) {
      throw const ReferencePhotoException('서버에 연결되어 있지 않아 사진을 공유할 수 없습니다.');
    }

    final name = displayName.trim();
    if (name.isEmpty) {
      throw const ReferencePhotoException('모프 이름을 입력해 주세요.');
    }

    final userId = await _service.requireUserId();
    if (userId == null) {
      throw const ReferencePhotoException(
        '익명 로그인에 실패했습니다. 네트워크를 확인하고 다시 시도해 주세요.',
      );
    }

    final photoId = _uuid.v4();
    // The first path segment must be the owner's id — the storage RLS policy
    // checks exactly that.
    final storagePath = '$userId/$photoId.jpg';

    try {
      await _client.storage
          .from(AppConfig.photoBucket)
          .uploadBinary(
            storagePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
    } on StorageException catch (error) {
      throw ReferencePhotoException('사진 업로드 실패: ${error.message}');
    }

    try {
      final row = await _client
          .from(_table)
          .insert({
            'id': photoId,
            'display_name': name,
            'morph_id': userMorphId(name),
            'storage_path': storagePath,
            'signature': signature.toJson(),
            'created_by': userId,
          })
          .select(_columns)
          .single();

      // Best effort: ask the server to embed the new photo so it starts
      // contributing to CLIP ranking. Failure only delays indexing — the
      // backfill action picks it up later.
      _requestIndexing(photoId);

      return ReferencePhoto.fromRow(
        row,
        publicUrlBuilder: _publicUrl,
        currentUserId: userId,
      );
    } on PostgrestException catch (error) {
      // Don't leave an orphan object behind if the row insert failed.
      await _client.storage
          .from(AppConfig.photoBucket)
          .remove([storagePath])
          .catchError((_) => <FileObject>[]);
      throw ReferencePhotoException('도감에 등록하지 못했습니다: ${error.message}');
    }
  }

  /// Deletes one of the current user's photos, along with its stored object.
  Future<void> deletePhoto(ReferencePhoto photo) async {
    if (!_service.isAvailable) {
      throw const ReferencePhotoException('서버에 연결되어 있지 않습니다.');
    }
    if (!photo.isMine) {
      throw const ReferencePhotoException('내가 올린 사진만 삭제할 수 있습니다.');
    }

    try {
      await _client.from(_table).delete().eq('id', photo.id);
      await _client.storage.from(AppConfig.photoBucket).remove([
        photo.storagePath,
      ]);
    } on PostgrestException catch (error) {
      throw ReferencePhotoException('삭제하지 못했습니다: ${error.message}');
    } on StorageException catch (error) {
      // The row is already gone, so the photo has effectively disappeared from
      // the library; a leftover object is a storage-cleanup concern only.
      debugPrint('CREHOONI: storage delete failed — ${error.message}');
    }
  }

  void _requestIndexing(String photoId) {
    _client.functions
        .invoke(
          AppConfig.clipFunction,
          body: {'action': 'index', 'photoId': photoId},
        )
        .catchError((Object error) {
          debugPrint('CREHOONI: CLIP indexing deferred — $error');
          return FunctionResponse(status: 0, data: null);
        });
  }

  /// Asks the edge function for CLIP similarities for [imageBytes].
  ///
  /// Returns null when the function is not deployed, errors, or the CLIP path is
  /// otherwise unavailable — the caller then uses the on-device colour score.
  Future<Map<String, double>?> fetchClipSimilarities(
    Uint8List imageBytes,
  ) async {
    if (!_service.isAvailable) return null;
    try {
      final response = await _client.functions.invoke(
        AppConfig.clipFunction,
        body: {'action': 'identify', 'image': base64Encode(imageBytes)},
      );

      final data = response.data;
      if (data is! Map || data['matches'] is! List) return null;

      final similarities = <String, double>{};
      for (final raw in data['matches'] as List) {
        if (raw is! Map) continue;
        final morphId = raw['morph_id'] as String?;
        final similarity = (raw['similarity'] as num?)?.toDouble();
        if (morphId == null || similarity == null) continue;
        // Keep the best score when catalog and community rows both matched.
        final existing = similarities[morphId];
        if (existing == null || similarity > existing) {
          similarities[morphId] = similarity;
        }
      }
      return similarities.isEmpty ? null : similarities;
    } catch (error) {
      debugPrint('CREHOONI: CLIP identify unavailable — $error');
      return null;
    }
  }
}
