import 'image_features.dart';

/// How a trait is passed on. Mirrors the `inheritance` field in `morphs.js`.
enum Inheritance {
  polygenic,
  recessive,
  incompleteDominant,
  combo,
  unknown;

  static Inheritance parse(String? raw) => switch (raw) {
    'polygenic' => Inheritance.polygenic,
    'recessive' => Inheritance.recessive,
    'incompleteDominant' => Inheritance.incompleteDominant,
    'combo' => Inheritance.combo,
    _ => Inheritance.unknown,
  };
}

/// Grouping used by the gallery filter. Mirrors `category` in `morphs.js`.
enum MorphCategory {
  base,
  pattern,
  color,
  genetic,
  combo,
  het,
  custom;

  static MorphCategory parse(String? raw) => switch (raw) {
    'base' => MorphCategory.base,
    'pattern' => MorphCategory.pattern,
    'color' => MorphCategory.color,
    'genetic' => MorphCategory.genetic,
    'combo' => MorphCategory.combo,
    'het' => MorphCategory.het,
    _ => MorphCategory.custom,
  };

  String get labelKo => switch (this) {
    MorphCategory.base => '베이스',
    MorphCategory.pattern => '패턴',
    MorphCategory.color => '컬러',
    MorphCategory.genetic => '유전자',
    MorphCategory.combo => '콤보',
    MorphCategory.het => '헷',
    MorphCategory.custom => '공유 사진',
  };
}

/// Korean won price band for a morph.
class PriceBand {
  const PriceBand({required this.min, required this.max});

  final int min;
  final int max;

  static const fallback = PriceBand(min: 80000, max: 250000);
}

/// A single morph entry — the Dart equivalent of one object in `MORPHS`.
class Morph {
  const Morph({
    required this.id,
    required this.nameKo,
    required this.nameEn,
    required this.category,
    required this.inheritance,
    required this.inheritanceKo,
    required this.description,
    required this.look,
    this.assetImage,
    this.aliases = const [],
    this.genes = const {},
    this.traits = const {},
    this.price = PriceBand.fallback,
    this.rarity = 1,
    this.signature,
    this.isCustom = false,
    this.extraPhotoIds = const [],
    this.extraImageUrls = const [],
    this.extraSignatures = const [],
    this.networkImage,
  });

  final String id;
  final String nameKo;
  final String nameEn;
  final MorphCategory category;
  final Inheritance inheritance;
  final String inheritanceKo;
  final String description;
  final String look;

  /// Bundled reference photo, e.g. `assets/morphs/lilly-white.jpg`.
  final String? assetImage;

  /// Remote reference photo used by community-contributed morphs.
  final String? networkImage;

  final List<String> aliases;

  /// Confirmed gene copy counts, 0–2, keyed by [GeneKey.id].
  final Map<String, int> genes;

  /// Polygenic pattern strengths, 0.0–1.0, keyed by [TraitKey.id].
  final Map<String, double> traits;

  final PriceBand price;

  /// 1–5, drives the rarity badge.
  final int rarity;

  /// Colour fingerprint used by the offline identification fallback.
  final ImageFeatures? signature;

  final bool isCustom;

  /// Ids of community photos attached to this morph (`custom:<uuid>` keys in the
  /// web version's embedding cache).
  final List<String> extraPhotoIds;

  /// Public URLs of those community photos.
  final List<String> extraImageUrls;

  /// Colour fingerprints of the attached community photos. Identification
  /// takes the best match against [signature] and these extras, so a real
  /// reference photo of this morph can outrank the bundled average.
  final List<ImageFeatures> extraSignatures;

  /// Preferred image for this morph: a bundled asset when available, otherwise
  /// the first remote photo.
  String? get primaryImage => assetImage ?? networkImage;

  bool get hasImage => primaryImage != null;

  int gene(String key) => genes[key] ?? 0;

  double trait(String key) => traits[key] ?? 0;

  Morph copyWith({
    String? nameKo,
    String? networkImage,
    ImageFeatures? signature,
    List<String>? extraPhotoIds,
    List<String>? extraImageUrls,
    List<ImageFeatures>? extraSignatures,
  }) {
    return Morph(
      id: id,
      nameKo: nameKo ?? this.nameKo,
      nameEn: nameEn,
      category: category,
      inheritance: inheritance,
      inheritanceKo: inheritanceKo,
      description: description,
      look: look,
      assetImage: assetImage,
      networkImage: networkImage ?? this.networkImage,
      aliases: aliases,
      genes: genes,
      traits: traits,
      price: price,
      rarity: rarity,
      signature: signature ?? this.signature,
      isCustom: isCustom,
      extraPhotoIds: extraPhotoIds ?? this.extraPhotoIds,
      extraImageUrls: extraImageUrls ?? this.extraImageUrls,
      extraSignatures: extraSignatures ?? this.extraSignatures,
    );
  }

  @override
  String toString() => 'Morph($id)';
}

/// A het-only option offered in the breeding form (`HET_OPTIONS`).
class HetOption {
  const HetOption({
    required this.id,
    required this.nameKo,
    required this.genes,
    required this.aliases,
  });

  final String id;
  final String nameKo;
  final Map<String, int> genes;
  final List<String> aliases;
}
