import 'package:crehooni/data/models/image_features.dart';
import 'package:crehooni/data/models/morph.dart';
import 'package:crehooni/data/models/reference_photo.dart';
import 'package:crehooni/data/morph_catalog.dart';
import 'package:crehooni/data/reference_photo_repository.dart';
import 'package:flutter_test/flutter_test.dart';

ReferencePhoto photo(
  String displayName, {
  String id = 'p1',
  bool isMine = false,
  ImageFeatures? signature,
}) {
  return ReferencePhoto(
    id: id,
    displayName: displayName,
    morphId: userMorphId(displayName),
    storagePath: 'user/$id.jpg',
    imageUrl: 'https://example.test/$id.jpg',
    createdAt: DateTime(2026, 8, 14),
    signature: signature,
    isMine: isMine,
  );
}

void main() {
  group('catalog integrity', () {
    test('holds all built-in morphs with unique ids', () {
      expect(morphCatalog, hasLength(28));
      expect(morphCatalog.map((m) => m.id).toSet(), hasLength(28));
    });

    test('every morph has a bundled image, signature and description', () {
      for (final morph in morphCatalog) {
        expect(morph.assetImage, isNotNull, reason: morph.id);
        expect(morph.assetImage, startsWith('assets/morphs/'));
        expect(morph.signature, isNotNull, reason: morph.id);
        expect(morph.description, isNotEmpty, reason: morph.id);
        expect(morph.aliases, isNotEmpty, reason: morph.id);
        expect(morph.rarity, inInclusiveRange(1, 5), reason: morph.id);
        expect(morph.price.min, lessThan(morph.price.max), reason: morph.id);
      }
    });

    test('gene copy counts stay within 0-2', () {
      for (final morph in morphCatalog) {
        for (final entry in morph.genes.entries) {
          expect(GeneKey.all, contains(entry.key));
          expect(entry.value, inInclusiveRange(0, 2), reason: morph.id);
        }
      }
    });

    test('trait strengths stay within 0-1 and use known keys', () {
      for (final morph in morphCatalog) {
        for (final entry in morph.traits.entries) {
          expect(TraitKey.all, contains(entry.key), reason: morph.id);
          expect(entry.value, inInclusiveRange(0, 1), reason: morph.id);
        }
      }
    });

    test('no alias is claimed by two different morphs', () {
      final owners = <String, String>{};
      for (final entry in allAliases) {
        final existing = owners[entry.alias];
        if (existing != null && existing != entry.morph.id) {
          fail(
            'alias "${entry.alias}" maps to both $existing and '
            '${entry.morph.id}',
          );
        }
        owners[entry.alias] = entry.morph.id;
      }
    });

    test('aliases are sorted longest first so specific names win', () {
      for (var i = 1; i < allAliases.length; i++) {
        expect(
          allAliases[i - 1].alias.length,
          greaterThanOrEqualTo(allAliases[i].alias.length),
        );
      }
    });

    test('morphImagePath resolves catalog ids and phenotype-only ids', () {
      expect(morphImagePath('lilly-white'), 'assets/morphs/lilly-white.jpg');
      expect(morphImagePath('normal'), 'assets/morphs/normal.jpg');
      expect(morphImagePath('unknown-id'), 'assets/morphs/unknown-id.jpg');
    });
  });

  group('mergeCatalog', () {
    test('with no photos returns exactly the bundled morphs', () {
      final snapshot = ReferencePhotoRepository.mergeCatalog(const []);
      expect(snapshot.morphs, hasLength(selectableMorphs.length));
      expect(snapshot.photos, isEmpty);
      expect(snapshot.communityMorphs, isEmpty);
    });

    test(
      'a decorated recognised name still attaches to the existing morph',
      () {
        final snapshot = ReferencePhotoRepository.mergeCatalog([
          photo('릴리화이트 수컷', id: 'decorated'),
        ]);
        final lilly = snapshot.byId('lilly-white')!;
        expect(lilly.extraPhotoIds, ['custom:decorated']);
        expect(snapshot.communityMorphs, isEmpty);
      },
    );

    test('linked photos keep their signatures for identification', () {
      const extra = ImageFeatures.signature(
        white: 0.91,
        orange: 0.02,
        yellow: 0.03,
        dark: 0.02,
        gray: 0.01,
        brown: 0.01,
        spots: 0.0,
        sat: 0.12,
      );
      final snapshot = ReferencePhotoRepository.mergeCatalog([
        photo('릴리 화이트', id: 'sig', signature: extra),
      ]);
      final lilly = snapshot.byId('lilly-white')!;
      expect(lilly.extraSignatures, hasLength(1));
      expect(lilly.extraSignatures.single.white, 0.91);
    });

    test('a recognised name attaches to the existing morph', () {
      final snapshot = ReferencePhotoRepository.mergeCatalog([
        photo('릴리 화이트', id: 'a'),
        photo('릴리', id: 'b'),
      ]);

      final lilly = snapshot.byId('lilly-white')!;
      expect(lilly.extraPhotoIds, ['custom:a', 'custom:b']);
      expect(lilly.extraImageUrls, hasLength(2));
      // Still uses its own bundled photo as the primary image.
      expect(lilly.primaryImage, 'assets/morphs/lilly-white.jpg');
      expect(snapshot.communityMorphs, isEmpty);
    });

    test('an unrecognised name becomes its own community morph', () {
      final snapshot = ReferencePhotoRepository.mergeCatalog([
        photo('우리집 별이', id: 'c'),
      ]);

      final community = snapshot.communityMorphs;
      expect(community, hasLength(1));
      expect(community.single.nameKo, '우리집 별이');
      expect(community.single.category, MorphCategory.custom);
      expect(community.single.isCustom, isTrue);
      expect(community.single.primaryImage, 'https://example.test/c.jpg');
      expect(community.single.extraPhotoIds, ['custom:c']);
    });

    test('several photos of the same unknown name collapse into one morph', () {
      final snapshot = ReferencePhotoRepository.mergeCatalog([
        photo('우리집 별이', id: 'c1'),
        photo('우리집 별이', id: 'c2'),
        photo('우리집 별이', id: 'c3'),
      ]);
      expect(snapshot.communityMorphs, hasLength(1));
      expect(snapshot.communityMorphs.single.extraImageUrls, hasLength(3));
    });

    test(
      'a community morph carries its signature so offline scoring works',
      () {
        const signature = ImageFeatures.signature(
          white: 0.5,
          orange: 0.1,
          yellow: 0.1,
          dark: 0.2,
          gray: 0.1,
          brown: 0.1,
          spots: 0.0,
          sat: 0.3,
        );
        final snapshot = ReferencePhotoRepository.mergeCatalog([
          photo('알 수 없는 개체', id: 'd', signature: signature),
        ]);
        expect(snapshot.communityMorphs.single.signature?.white, 0.5);
      },
    );

    test('myPhotos returns only the current user rows, newest first', () {
      final snapshot = ReferencePhotoRepository.mergeCatalog([
        ReferencePhoto(
          id: 'old',
          displayName: '할리퀸',
          morphId: 'harlequin',
          storagePath: 'u/old.jpg',
          imageUrl: 'https://example.test/old.jpg',
          createdAt: DateTime(2026, 1, 1),
          isMine: true,
        ),
        ReferencePhoto(
          id: 'new',
          displayName: '팬텀',
          morphId: 'phantom',
          storagePath: 'u/new.jpg',
          imageUrl: 'https://example.test/new.jpg',
          createdAt: DateTime(2026, 8, 1),
          isMine: true,
        ),
        photo('플레임', id: 'other'),
      ]);

      expect(snapshot.myPhotos.map((p) => p.id), ['new', 'old']);
      expect(snapshot.sharedPhotos.map((p) => p.id), ['other', 'new', 'old']);
    });

    test('catalogKey preserves the web version custom: convention', () {
      expect(photo('할리퀸', id: 'xyz').catalogKey, 'custom:xyz');
    });
  });

  group('ReferencePhoto.fromRow', () {
    test('maps a Postgres row and flags ownership', () {
      final parsed = ReferencePhoto.fromRow(
        {
          'id': 'row-1',
          'display_name': '  릴리 화이트  ',
          'morph_id': 'lilly-white',
          'storage_path': 'me/row-1.jpg',
          'signature': {'white': 0.4, 'sat': 0.3},
          'has_embedding': true,
          'created_by': 'me',
          'created_at': '2026-08-14T05:00:00Z',
        },
        publicUrlBuilder: (path) => 'https://cdn.test/$path',
        currentUserId: 'me',
      );

      expect(parsed.displayName, '릴리 화이트');
      expect(parsed.imageUrl, 'https://cdn.test/me/row-1.jpg');
      expect(parsed.isMine, isTrue);
      expect(parsed.hasEmbedding, isTrue);
      expect(parsed.signature?.white, 0.4);
    });

    test('someone else\'s row is not mine and tolerates missing fields', () {
      final parsed = ReferencePhoto.fromRow(
        {
          'id': 'row-2',
          'display_name': '할로윈',
          'morph_id': 'halloween',
          'storage_path': 'them/row-2.jpg',
          'created_by': 'them',
        },
        publicUrlBuilder: (path) => 'https://cdn.test/$path',
        currentUserId: 'me',
      );

      expect(parsed.isMine, isFalse);
      expect(parsed.hasEmbedding, isFalse);
      expect(parsed.signature, isNull);
    });
  });
}
