import 'package:crehooni/core/config.dart';
import 'package:crehooni/data/models/morph.dart';
import 'package:crehooni/data/reference_photo_repository.dart';
import 'package:crehooni/data/supabase_service.dart';
import 'package:crehooni/domain/image_analysis.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// End-to-end check of the reference photo feature against a real project.
///
/// This is deliberately *not* under `test/`, so `flutter test` and CI never run
/// it. Run it against a device with keys supplied:
///
/// ```sh
/// flutter test integration_test/reference_photo_live_test.dart \
///   -d <device-id> --dart-define-from-file=env.json
/// ```
///
/// It creates one row plus one storage object and removes both again, so a
/// successful run leaves the project exactly as it found it.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// A recognisable, unique name so a failed run is easy to spot and clean up.
  final displayName = '자동검증 임시사진 ${DateTime.now().microsecondsSinceEpoch}';

  /// A small photo-like JPEG: an orange body with a few dark spots, so the
  /// colour signature is non-degenerate.
  Uint8List sampleJpeg() {
    final image = img.Image(width: 320, height: 240);
    img.fill(image, color: img.ColorRgb8(214, 122, 48));
    for (var i = 0; i < 6; i++) {
      img.fillCircle(
        image,
        x: 40 + i * 45,
        y: 90 + (i.isEven ? 0 : 50),
        radius: 14,
        color: img.ColorRgb8(28, 24, 20),
      );
    }
    return Uint8List.fromList(img.encodeJpg(image, quality: 90));
  }

  test('a photo can be contributed, read back, and deleted', () async {
    if (!AppConfig.hasSupabase) {
      markTestSkipped('No SUPABASE_URL / SUPABASE_ANON_KEY — nothing to test.');
      return;
    }

    final service = SupabaseService.instance;
    await service.initialise();
    expect(
      service.isAvailable,
      isTrue,
      reason: 'Supabase did not initialise: ${service.unavailableReason}',
    );

    final userId = await service.requireUserId();
    expect(
      userId,
      isNotNull,
      reason:
          'Anonymous sign-in failed. Enable Dashboard → Authentication → '
          'Sign In / Providers → Anonymous sign-ins. '
          '(${service.unavailableReason})',
    );

    final repository = ReferencePhotoRepository(service: service);

    // 1. Upload, mirroring exactly what CatalogNotifier.addPhoto does.
    final upload = ImageAnalysis.encodeForUpload(
      sampleJpeg(),
      maxEdge: AppConfig.uploadMaxEdge,
      quality: AppConfig.uploadJpegQuality,
    );
    expect(upload, isNotNull, reason: 'encodeForUpload returned null');

    final signature = ImageAnalysis.fromBytes(upload!);
    expect(signature, isNotNull, reason: 'fromBytes returned null');
    expect(
      signature!.orange,
      greaterThan(0.3),
      reason: 'the sample should read as mostly orange',
    );

    final created = await repository.addPhoto(
      displayName: displayName,
      imageBytes: upload,
      signature: signature,
    );

    expect(created.displayName, displayName);
    expect(created.isMine, isTrue);
    expect(created.hasEmbedding, isFalse, reason: 'CLIP indexing is deferred');
    expect(
      created.storagePath,
      startsWith('$userId/'),
      reason: 'storage RLS requires the owner id as the first path segment',
    );
    expect(created.imageUrl, contains(AppConfig.photoBucket));

    // 2. The object is really in the bucket.
    final objects = await Supabase.instance.client.storage
        .from(AppConfig.photoBucket)
        .list(path: userId);
    expect(
      objects.map((o) => o.name),
      contains(created.storagePath.split('/').last),
    );

    // 3. It comes back from a plain read and merges into the catalog as its own
    // community morph, since the name is not in the bundled catalog.
    final photos = await repository.fetchPhotos();
    final fetched = photos.where((p) => p.id == created.id);
    expect(fetched, hasLength(1));
    expect(fetched.single.isMine, isTrue);
    expect(
      fetched.single.signature?.orange,
      closeTo(signature.orange, 0.001),
      reason: 'the colour signature must survive the jsonb round trip',
    );

    final snapshot = ReferencePhotoRepository.mergeCatalog(photos);
    final community = snapshot.morphs.where((m) => m.nameKo == displayName);
    expect(community, hasLength(1));
    expect(community.single.isCustom, isTrue);
    expect(community.single.category, MorphCategory.custom);
    expect(community.single.extraImageUrls, contains(created.imageUrl));
    expect(snapshot.myPhotos.map((p) => p.id), contains(created.id));

    // 4. Delete removes both the row and the object.
    await repository.deletePhoto(fetched.single);

    final after = await repository.fetchPhotos();
    expect(after.where((p) => p.id == created.id), isEmpty);

    final objectsAfter = await Supabase.instance.client.storage
        .from(AppConfig.photoBucket)
        .list(path: userId);
    expect(
      objectsAfter.map((o) => o.name),
      isNot(contains(created.storagePath.split('/').last)),
    );

    debugPrint('LIVE CHECK OK: contributed and removed "$displayName"');
  });
}
