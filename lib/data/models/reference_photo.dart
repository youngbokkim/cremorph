import 'image_features.dart';

/// A community-contributed reference photo — one row of `reference_photos`.
class ReferencePhoto {
  const ReferencePhoto({
    required this.id,
    required this.displayName,
    required this.morphId,
    required this.storagePath,
    required this.imageUrl,
    required this.createdAt,
    this.signature,
    this.isMine = false,
    this.hasEmbedding = false,
  });

  final String id;

  /// The morph name exactly as the contributor typed it.
  final String displayName;

  /// Catalog id, or a `user-` slug for names not in the catalog.
  final String morphId;

  final String storagePath;

  /// Public URL for display.
  final String imageUrl;

  final DateTime createdAt;

  /// Colour fingerprint, letting the offline scorer rank this photo without
  /// downloading it.
  final ImageFeatures? signature;

  /// Contributed by the current (anonymous) user, so it can be deleted here.
  final bool isMine;

  /// Has a CLIP embedding stored, so server-side ranking can use it.
  final bool hasEmbedding;

  /// Key used to identify this photo inside a morph's `extraPhotoIds`,
  /// preserving the `custom:<id>` convention from the web version.
  String get catalogKey => 'custom:$id';

  static ReferencePhoto fromRow(
    Map<String, dynamic> row, {
    required String Function(String storagePath) publicUrlBuilder,
    String? currentUserId,
  }) {
    final storagePath = row['storage_path'] as String;
    final createdBy = row['created_by'] as String?;
    return ReferencePhoto(
      id: row['id'] as String,
      displayName: (row['display_name'] as String?)?.trim() ?? '이름 없음',
      morphId: row['morph_id'] as String,
      storagePath: storagePath,
      imageUrl: publicUrlBuilder(storagePath),
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      signature: ImageFeatures.fromJson(
        (row['signature'] as Map?)?.cast<String, dynamic>(),
      ),
      isMine: createdBy != null && createdBy == currentUserId,
      // `embedding` is intentionally not selected — a 512-float vector per row
      // would dominate the payload. The server reports only whether it exists.
      hasEmbedding: row['has_embedding'] as bool? ?? false,
    );
  }
}
