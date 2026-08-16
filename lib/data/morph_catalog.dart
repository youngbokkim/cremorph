import 'models/image_features.dart';
import 'models/morph.dart';

/// Confirmed single-locus genes tracked by the breeding calculator.
abstract final class GeneKey {
  static const lillyWhite = 'lillyWhite';
  static const axanthic = 'axanthic';
  static const phantom = 'phantom';
  static const cappuccino = 'cappuccino';
  static const sable = 'sable';
  static const softScale = 'softScale';
  static const dunkel = 'dunkel';
  static const hypo = 'hypo';
  static const charcoal = 'charcoal';

  /// Iteration order matters: it fixes the order of Punnett loci.
  static const all = <String>[
    lillyWhite,
    axanthic,
    phantom,
    cappuccino,
    sable,
    softScale,
    dunkel,
    hypo,
    charcoal,
  ];
}

/// Polygenic pattern traits, approximated rather than inherited by Mendel.
abstract final class TraitKey {
  static const flame = 'flame';
  static const harlequin = 'harlequin';
  static const extreme = 'extreme';
  static const pinstripe = 'pinstripe';
  static const dalmatian = 'dalmatian';
  static const tiger = 'tiger';
  static const halloween = 'halloween';
  static const creamsicle = 'creamsicle';
  static const tricolor = 'tricolor';
  static const lavender = 'lavender';
  static const chocolate = 'chocolate';
  static const moonglow = 'moonglow';
  static const whiteWall = 'whiteWall';
  static const emptyback = 'emptyback';

  static const all = <String>[
    flame,
    harlequin,
    extreme,
    pinstripe,
    dalmatian,
    tiger,
    halloween,
    creamsicle,
    tricolor,
    lavender,
    chocolate,
    moonglow,
    whiteWall,
    emptyback,
  ];
}

/// Display metadata for a confirmed gene (`GENE_META`).
class GeneMeta {
  const GeneMeta({
    required this.name,
    required this.mode,
    required this.labels,
    required this.imageId,
    this.lethalSuper = false,
    this.cautionSuper = false,
  });

  final String name;
  final Inheritance mode;

  /// Labels for 0, 1 and 2 copies.
  final List<String> labels;
  final String imageId;

  /// Two copies are lethal (Lilly White).
  final bool lethalSuper;

  /// Two copies carry health risks (Cappuccino).
  final bool cautionSuper;
}

/// Display metadata for a polygenic trait (`TRAIT_META`).
class TraitMeta {
  const TraitMeta({required this.name, required this.imageId});

  final String name;
  final String imageId;
}

const geneMeta = <String, GeneMeta>{
  GeneKey.lillyWhite: GeneMeta(
    name: '릴리 화이트',
    mode: Inheritance.incompleteDominant,
    labels: ['없음', '릴리 화이트', '슈퍼 릴리 화이트'],
    lethalSuper: true,
    imageId: 'lilly-white',
  ),
  GeneKey.axanthic: GeneMeta(
    name: '아잔틱',
    mode: Inheritance.recessive,
    labels: ['없음', '헷 아잔틱', '비주얼 아잔틱'],
    imageId: 'axanthic',
  ),
  GeneKey.phantom: GeneMeta(
    name: '팬텀',
    mode: Inheritance.recessive,
    labels: ['없음', '헷 팬텀', '비주얼 팬텀'],
    imageId: 'phantom',
  ),
  GeneKey.cappuccino: GeneMeta(
    name: '카푸치노',
    mode: Inheritance.incompleteDominant,
    labels: ['없음', '카푸치노', '슈퍼 카푸치노'],
    cautionSuper: true,
    imageId: 'cappuccino',
  ),
  GeneKey.sable: GeneMeta(
    name: '세이블',
    mode: Inheritance.incompleteDominant,
    labels: ['없음', '세이블', '슈퍼 세이블'],
    imageId: 'sable',
  ),
  GeneKey.softScale: GeneMeta(
    name: '소프트스케일',
    mode: Inheritance.incompleteDominant,
    labels: ['없음', '소프트스케일', '슈퍼 소프트스케일'],
    cautionSuper: true,
    imageId: 'soft-scale',
  ),
  GeneKey.dunkel: GeneMeta(
    name: '던켈',
    mode: Inheritance.incompleteDominant,
    labels: ['없음', '던켈', '슈퍼 던켈'],
    cautionSuper: true,
    imageId: 'dunkel',
  ),
  GeneKey.hypo: GeneMeta(
    name: '하이포',
    mode: Inheritance.recessive,
    labels: ['없음', '헷 하이포', '비주얼 하이포'],
    imageId: 'hypo',
  ),
  GeneKey.charcoal: GeneMeta(
    name: '차콜',
    mode: Inheritance.recessive,
    labels: ['없음', '헷 차콜', '비주얼 차콜'],
    imageId: 'charcoal',
  ),
};

const traitMeta = <String, TraitMeta>{
  TraitKey.flame: TraitMeta(name: '플레임', imageId: 'flame'),
  TraitKey.harlequin: TraitMeta(name: '할리퀸', imageId: 'harlequin'),
  TraitKey.extreme: TraitMeta(name: '익스트림', imageId: 'extreme-harlequin'),
  TraitKey.pinstripe: TraitMeta(name: '핀스트라이프', imageId: 'pinstripe'),
  TraitKey.dalmatian: TraitMeta(name: '달마시안', imageId: 'dalmatian'),
  TraitKey.tiger: TraitMeta(name: '타이거', imageId: 'tiger'),
  TraitKey.halloween: TraitMeta(name: '할로윈', imageId: 'halloween'),
  TraitKey.creamsicle: TraitMeta(name: '크림시클', imageId: 'creamsicle'),
  TraitKey.tricolor: TraitMeta(name: '트라이컬러', imageId: 'tricolor'),
  TraitKey.lavender: TraitMeta(name: '라벤더', imageId: 'lavender'),
  TraitKey.chocolate: TraitMeta(name: '초콜릿', imageId: 'chocolate'),
  TraitKey.moonglow: TraitMeta(name: '문글로우', imageId: 'moonglow'),
  TraitKey.whiteWall: TraitMeta(name: '화이트월', imageId: 'white-wall'),
  TraitKey.emptyback: TraitMeta(name: '엠티백', imageId: 'emptyback'),
};

String _asset(String id) => 'assets/morphs/$id.jpg';

/// Built-in morphs shown in breeding, the gallery, and identification.
final List<Morph> morphCatalog = <Morph>[
  Morph(
    id: 'normal',
    nameKo: '노멀',
    nameEn: 'Normal / Wild Type',
    category: MorphCategory.base,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성',
    description:
        '야생형에 가까운 기본 체색입니다. 올리브·벅스킨·브라운 톤이 많고 옆구리 무늬는 적습니다. 다른 모프의 바탕이 됩니다.',
    look: '갈색·올리브 바탕, 무늬가 거의 없거나 약함',
    assetImage: _asset('normal'),
    aliases: ['노멀', '노말', '와일드', '와일드타입', '일반', 'normal', 'wild', 'wildtype'],
    genes: {
      GeneKey.lillyWhite: 0,
      GeneKey.axanthic: 0,
      GeneKey.phantom: 0,
      GeneKey.cappuccino: 0,
    },
    price: PriceBand(min: 50000, max: 150000),
    rarity: 1,
    signature: ImageFeatures.signature(
      white: 0.08,
      orange: 0.12,
      yellow: 0.18,
      dark: 0.28,
      gray: 0.12,
      brown: 0.58,
      spots: 0.04,
      sat: 0.32,
    ),
  ),
  Morph(
    id: 'flame',
    nameKo: '플레임',
    nameEn: 'Flame',
    category: MorphCategory.pattern,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 (선발 교배)',
    description:
        '등(등판)과 머리에만 크림·노란 불꽃 무늬가 있고, 옆구리와 다리에는 무늬가 거의 없습니다. 할리퀸의 약한 형태로 보는 경우가 많습니다.',
    look: '등·머리만 밝은 무늬, 옆구리·다리는 단색',
    assetImage: _asset('flame'),
    aliases: ['플레임', 'flame', '불꽃'],
    traits: {TraitKey.flame: 1},
    price: PriceBand(min: 80000, max: 250000),
    rarity: 2,
    signature: ImageFeatures.signature(
      white: 0.18,
      orange: 0.22,
      yellow: 0.32,
      dark: 0.3,
      gray: 0.08,
      brown: 0.45,
      spots: 0.05,
      sat: 0.42,
    ),
  ),
  Morph(
    id: 'harlequin',
    nameKo: '할리퀸',
    nameEn: 'Harlequin',
    category: MorphCategory.pattern,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 (선발 교배)',
    description:
        '플레임보다 무늬가 옆구리와 다리까지 내려온 형태입니다. 크레스티드게코에서 가장 흔하고 인기 있는 패턴 모프입니다. 커버리지가 넓을수록 가격이 올라갑니다.',
    look: '크림·노란 무늬가 옆구리와 다리까지 퍼짐',
    assetImage: _asset('harlequin'),
    aliases: ['할리퀸', '할리', 'harley', 'harlequin'],
    traits: {TraitKey.harlequin: 0.8},
    price: PriceBand(min: 120000, max: 400000),
    rarity: 2,
    signature: ImageFeatures.signature(
      white: 0.28,
      orange: 0.2,
      yellow: 0.38,
      dark: 0.22,
      gray: 0.06,
      brown: 0.4,
      spots: 0.06,
      sat: 0.48,
    ),
  ),
  Morph(
    id: 'extreme-harlequin',
    nameKo: '익스트림 할리퀸',
    nameEn: 'Extreme Harlequin',
    category: MorphCategory.pattern,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 (고커버리지)',
    description:
        '할리퀸 무늬가 몸 대부분을 덮은 고퀄리티 개체입니다. 브리더 사이에서는 XXX로 부르기도 하지만, 단일 유전자가 아니라 패턴이 극단적으로 쌓인 표현형입니다.',
    look: '밝은 무늬가 몸 대부분을 덮고 바탕색은 조금만 남음',
    assetImage: _asset('extreme-harlequin'),
    aliases: [
      '익스트림할리퀸',
      '익스트림',
      '익할',
      'xxx',
      'extreme',
      'extremeharlequin',
      '슈퍼할리퀸',
    ],
    traits: {TraitKey.harlequin: 1, TraitKey.extreme: 1},
    price: PriceBand(min: 250000, max: 1200000),
    rarity: 4,
    signature: ImageFeatures.signature(
      white: 0.48,
      orange: 0.18,
      yellow: 0.42,
      dark: 0.12,
      gray: 0.05,
      brown: 0.22,
      spots: 0.05,
      sat: 0.5,
    ),
  ),
  Morph(
    id: 'pinstripe',
    nameKo: '핀스트라이프',
    nameEn: 'Pinstripe',
    category: MorphCategory.pattern,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 · 우성에 가깝게 유전',
    description:
        '등 양옆으로 융기된 비늘이 크림색 두 줄(핀)을 만듭니다. 줄이 머리부터 꼬리까지 끊기지 않으면 풀 핀, 중간에 끊기면 파셜 핀입니다. 할리퀸·달마시안과 자주 조합됩니다.',
    look: '등을 따라 올라온 크림색 두 줄',
    assetImage: _asset('pinstripe'),
    aliases: ['핀스트라이프', '핀스', '핀', 'pinstripe', 'pin', '풀핀'],
    traits: {TraitKey.pinstripe: 1},
    price: PriceBand(min: 180000, max: 700000),
    rarity: 3,
    signature: ImageFeatures.signature(
      white: 0.22,
      orange: 0.14,
      yellow: 0.28,
      dark: 0.24,
      gray: 0.08,
      brown: 0.42,
      spots: 0.04,
      sat: 0.4,
    ),
  ),
  Morph(
    id: 'dalmatian',
    nameKo: '달마시안',
    nameEn: 'Dalmatian',
    category: MorphCategory.pattern,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 (점 밀도는 선발)',
    description:
        '몸 곳곳에 검은 점(또는 빨간 점)이 찍힙니다. 점의 크기·개수·분포가 퀄리티를 가릅니다. 점이 매우 많으면 슈퍼 달마시안입니다.',
    look: '바탕색 위에 동그란 검은 점',
    assetImage: _asset('dalmatian'),
    aliases: ['달마시안', '달마', '달마시안점', 'dalmatian', 'dal', '스팟'],
    traits: {TraitKey.dalmatian: 0.7},
    price: PriceBand(min: 150000, max: 550000),
    rarity: 3,
    signature: ImageFeatures.signature(
      white: 0.2,
      orange: 0.12,
      yellow: 0.35,
      dark: 0.22,
      gray: 0.08,
      brown: 0.28,
      spots: 0.55,
      sat: 0.38,
    ),
  ),
  Morph(
    id: 'super-dalmatian',
    nameKo: '슈퍼 달마시안',
    nameEn: 'Super Dalmatian',
    category: MorphCategory.pattern,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 (점이 매우 밀집)',
    description: '점이 몸 전체를 빽빽하게 덮은 달마시안입니다. 점 크기와 대비가 좋을수록 고가로 거래됩니다.',
    look: '검은 점이 몸 전체에 매우 많음',
    assetImage: _asset('super-dalmatian'),
    aliases: ['슈퍼달마시안', '슈퍼달마', 'superdal', 'superdalmatian'],
    traits: {TraitKey.dalmatian: 1},
    price: PriceBand(min: 350000, max: 1300000),
    rarity: 4,
    signature: ImageFeatures.signature(
      white: 0.16,
      orange: 0.1,
      yellow: 0.3,
      dark: 0.38,
      gray: 0.1,
      brown: 0.25,
      spots: 0.88,
      sat: 0.36,
    ),
  ),
  Morph(
    id: 'tiger',
    nameKo: '타이거',
    nameEn: 'Tiger',
    category: MorphCategory.pattern,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성',
    description: '옆구리를 가로지르는 호랑이 줄무늬입니다. 줄이 더 꼬이고 깨지면 브린들(Brindle)로 부르기도 합니다.',
    look: '세로·대각선 줄무늬가 옆구리를 감쌈',
    assetImage: _asset('tiger'),
    aliases: ['타이거', '호랑이', 'tiger', '브린들', 'brindle'],
    traits: {TraitKey.tiger: 1},
    price: PriceBand(min: 100000, max: 350000),
    rarity: 2,
    signature: ImageFeatures.signature(
      white: 0.1,
      orange: 0.28,
      yellow: 0.2,
      dark: 0.32,
      gray: 0.08,
      brown: 0.4,
      spots: 0.08,
      sat: 0.44,
    ),
  ),
  Morph(
    id: 'halloween',
    nameKo: '할로윈',
    nameEn: 'Halloween',
    category: MorphCategory.color,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 (검은 바탕 + 오렌지 무늬)',
    description:
        '검정·매우 어두운 바탕에 선명한 오렌지 무늬만 있는 배색입니다. 노랑·크림이 보이면 할로윈으로 보지 않는 것이 일반적입니다.',
    look: '블랙 바탕 + 비비드 오렌지, 노랑/크림 없음',
    assetImage: _asset('halloween'),
    aliases: ['할로윈', '할윈', 'halloween', '할러윈'],
    traits: {TraitKey.halloween: 1, TraitKey.harlequin: 0.7},
    price: PriceBand(min: 200000, max: 800000),
    rarity: 3,
    signature: ImageFeatures.signature(
      white: 0.04,
      orange: 0.55,
      yellow: 0.08,
      dark: 0.55,
      gray: 0.1,
      brown: 0.22,
      spots: 0.06,
      sat: 0.62,
    ),
  ),
  Morph(
    id: 'creamsicle',
    nameKo: '크림시클',
    nameEn: 'Creamsicle',
    category: MorphCategory.color,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 (오렌지 + 크림)',
    description: '오렌지·탠저린 바탕에 화이트·크림 무늬가 올라간 배색입니다. 아이스크림 크림시클처럼 보여 붙은 이름입니다.',
    look: '선명한 오렌지 + 하얀 크림 무늬',
    assetImage: _asset('creamsicle'),
    aliases: ['크림시클', 'creamsicle', '오렌지크림', '탠저린'],
    traits: {TraitKey.creamsicle: 1, TraitKey.harlequin: 0.6},
    price: PriceBand(min: 180000, max: 750000),
    rarity: 3,
    signature: ImageFeatures.signature(
      white: 0.32,
      orange: 0.58,
      yellow: 0.18,
      dark: 0.1,
      gray: 0.04,
      brown: 0.15,
      spots: 0.04,
      sat: 0.66,
    ),
  ),
  Morph(
    id: 'tricolor',
    nameKo: '트라이컬러',
    nameEn: 'Tri-color',
    category: MorphCategory.color,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 (세 가지 색)',
    description:
        '어두운 바탕 + 오렌지 + 크림/화이트가 한 개체에 분명하게 나뉜 3색 패턴입니다. 색 경계가 선명할수록 가치가 높습니다.',
    look: '어두운 바탕, 오렌지, 크림이 동시에 보임',
    assetImage: _asset('tricolor'),
    aliases: ['트라이컬러', '트라이', '삼색', 'tricolor', 'tri-color', 'tricolour'],
    traits: {TraitKey.tricolor: 1, TraitKey.harlequin: 0.7},
    price: PriceBand(min: 220000, max: 900000),
    rarity: 3,
    signature: ImageFeatures.signature(
      white: 0.28,
      orange: 0.42,
      yellow: 0.16,
      dark: 0.32,
      gray: 0.06,
      brown: 0.22,
      spots: 0.05,
      sat: 0.58,
    ),
  ),
  Morph(
    id: 'phantom',
    nameKo: '팬텀',
    nameEn: 'Phantom',
    category: MorphCategory.genetic,
    inheritance: Inheritance.recessive,
    inheritanceKo: '열성 (비주얼은 유전자 2개)',
    description:
        '멜라닌이 늘어 전체적으로 어둡고 대비가 깊어집니다. 열성이라 부모 양쪽이 유전자를 가져야 비주얼이 나옵니다. 릴리·핀과 조합하면 팬텀 릴리, 팬텀 핀이 됩니다.',
    look: '전체적으로 매우 어둡고 흰 무늬가 줄어듦',
    assetImage: _asset('phantom'),
    aliases: ['팬텀', '팬톰', 'phantom'],
    genes: {GeneKey.phantom: 2},
    price: PriceBand(min: 200000, max: 800000),
    rarity: 4,
    signature: ImageFeatures.signature(
      white: 0.06,
      orange: 0.08,
      yellow: 0.06,
      dark: 0.72,
      gray: 0.22,
      brown: 0.35,
      spots: 0.04,
      sat: 0.22,
    ),
  ),
  Morph(
    id: 'lilly-white',
    nameKo: '릴리 화이트',
    nameEn: 'Lilly White',
    category: MorphCategory.genetic,
    inheritance: Inheritance.incompleteDominant,
    inheritanceKo: '불완전 우성 · 슈퍼폼은 치사',
    description:
        '2010년대 Lilly Exotics에서 확립된 불완전 우성 유전자입니다. 크림·화이트 커버리지가 넓고 자라면서 더 하얘집니다. 릴리끼리 교배하면 슈퍼 릴리(치사)가 25%라 절대 권장하지 않습니다.',
    look: '몸 옆·배·꼬리가 하얗고 등·머리는 유색',
    assetImage: _asset('lilly-white'),
    aliases: ['릴리화이트', '릴리', '릴리화', 'lilly', 'lillywhite', 'lily', 'lilywhite'],
    genes: {GeneKey.lillyWhite: 1},
    price: PriceBand(min: 250000, max: 2000000),
    rarity: 5,
    signature: ImageFeatures.signature(
      white: 0.55,
      orange: 0.28,
      yellow: 0.16,
      dark: 0.08,
      gray: 0.06,
      brown: 0.12,
      spots: 0.03,
      sat: 0.45,
    ),
  ),
  Morph(
    id: 'axanthic',
    nameKo: '아잔틱',
    nameEn: 'Axanthic',
    category: MorphCategory.genetic,
    inheritance: Inheritance.recessive,
    inheritanceKo: '열성 (노랑·빨강 색소 제거)',
    description:
        '잔토포어(노랑·빨강 색소)가 없어 흑·백·은·회색만 남습니다. 열성이라 비주얼끼리 교배하면 100% 아잔틱, 헷끼리면 25% 비주얼입니다.',
    look: '노랑/오렌지 없이 실버·차콜·화이트',
    assetImage: _asset('axanthic'),
    aliases: ['아잔틱', '액산틱', '악산틱', 'axanthic', 'axan'],
    genes: {GeneKey.axanthic: 2},
    price: PriceBand(min: 700000, max: 3500000),
    rarity: 5,
    signature: ImageFeatures.signature(
      white: 0.22,
      orange: 0.02,
      yellow: 0.03,
      dark: 0.48,
      gray: 0.62,
      brown: 0.12,
      spots: 0.08,
      sat: 0.12,
    ),
  ),
  Morph(
    id: 'cappuccino',
    nameKo: '카푸치노',
    nameEn: 'Cappuccino',
    category: MorphCategory.genetic,
    inheritance: Inheritance.incompleteDominant,
    inheritanceKo: '불완전 우성 · 슈퍼폼은 건강 이슈',
    description:
        '한국 Reptile City에서 확인된 불완전 우성입니다. 모카·에스프레소 톤의 어두운 몸과 독특한 두상입니다. 카푸끼리 교배하면 슈퍼 카푸(멜라니스틱)가 나오며 기형 위험이 있어 비추천입니다. 세이블과 같은 좌위입니다.',
    look: '커피색 어두운 몸, 크레스트가 약한 편',
    assetImage: _asset('cappuccino'),
    aliases: ['카푸치노', '카푸', 'cappuccino', 'capp', 'cap'],
    genes: {GeneKey.cappuccino: 1},
    price: PriceBand(min: 400000, max: 2500000),
    rarity: 5,
    signature: ImageFeatures.signature(
      white: 0.1,
      orange: 0.12,
      yellow: 0.08,
      dark: 0.58,
      gray: 0.18,
      brown: 0.55,
      spots: 0.04,
      sat: 0.28,
    ),
  ),
  Morph(
    id: 'frappuccino',
    nameKo: '프라푸치노',
    nameEn: 'Frappuccino',
    category: MorphCategory.combo,
    inheritance: Inheritance.combo,
    inheritanceKo: '릴리 화이트 + 카푸치노 (각각 불완전 우성)',
    description:
        '릴리 화이트와 카푸치노를 한 개체에 모은 콤보입니다. 커피 바탕에 릴리의 크림 화이트가 올라갑니다. 릴리 × 카푸 교배 시 25% 확률로 나옵니다.',
    look: '모카 바탕 + 넓은 크림 화이트 커버리지',
    assetImage: _asset('frappuccino'),
    aliases: ['프라푸치노', '프라푸', 'frappuccino', 'frap', '프라페'],
    genes: {GeneKey.lillyWhite: 1, GeneKey.cappuccino: 1},
    price: PriceBand(min: 800000, max: 4500000),
    rarity: 5,
    signature: ImageFeatures.signature(
      white: 0.42,
      orange: 0.12,
      yellow: 0.1,
      dark: 0.38,
      gray: 0.14,
      brown: 0.4,
      spots: 0.03,
      sat: 0.32,
    ),
  ),
  Morph(
    id: 'lilly-axanthic',
    nameKo: '릴리 아잔틱',
    nameEn: 'Lilly Axanthic',
    category: MorphCategory.combo,
    inheritance: Inheritance.combo,
    inheritanceKo: '릴리 화이트 + 비주얼 아잔틱',
    description:
        '릴잔틱이라고도 합니다. 아잔틱의 흑백 팔레트 위에 릴리의 화이트가 올라간 초고가 콤보입니다. 노랑·오렌지가 전혀 없습니다.',
    look: '실버·차콜 바탕에 순백 무늬, 웜톤 없음',
    assetImage: _asset('lilly-axanthic'),
    aliases: ['릴리아잔틱', '릴잔틱', '릴리액산틱', 'lillyaxanthic', 'lilyaxanthic'],
    genes: {GeneKey.lillyWhite: 1, GeneKey.axanthic: 2},
    price: PriceBand(min: 1500000, max: 6000000),
    rarity: 5,
    signature: ImageFeatures.signature(
      white: 0.48,
      orange: 0.01,
      yellow: 0.02,
      dark: 0.32,
      gray: 0.55,
      brown: 0.08,
      spots: 0.04,
      sat: 0.1,
    ),
  ),
  Morph(
    id: 'phantom-lilly',
    nameKo: '팬텀 릴리',
    nameEn: 'Phantom Lilly White',
    category: MorphCategory.combo,
    inheritance: Inheritance.combo,
    inheritanceKo: '릴리 화이트 + 비주얼 팬텀',
    description: '팬텀의 멜라닌과 릴리의 화이트가 겹칩니다. 어두운 몸통에 하양 커버리지가 또렷하게 대비됩니다.',
    look: '어두운 몸 + 릴리 화이트 패턴',
    assetImage: _asset('phantom-lilly'),
    aliases: ['팬텀릴리', '팬텀릴리화이트', 'phantomlilly', 'phantomlily'],
    genes: {GeneKey.lillyWhite: 1, GeneKey.phantom: 2},
    price: PriceBand(min: 500000, max: 2200000),
    rarity: 5,
    signature: ImageFeatures.signature(
      white: 0.4,
      orange: 0.08,
      yellow: 0.06,
      dark: 0.45,
      gray: 0.18,
      brown: 0.22,
      spots: 0.03,
      sat: 0.28,
    ),
  ),
  Morph(
    id: 'sable',
    nameKo: '세이블',
    nameEn: 'Sable',
    category: MorphCategory.genetic,
    inheritance: Inheritance.incompleteDominant,
    inheritanceKo: '불완전 우성 · 카푸치노와 같은 좌위로 보기도 함',
    description:
        '벨벳처럼 어두운 몸과 부드러운 대비가 특징인 불완전 우성입니다. 카푸치노와 같은 좌위라는 연구가 있어 카푸와 세이블끼리의 슈퍼폼은 피합니다.',
    look: '짙은 벨벳 브라운·블랙, 무늬 대비가 부드러움',
    assetImage: _asset('cappuccino'),
    aliases: ['세이블', 'sable'],
    genes: {GeneKey.sable: 1},
    price: PriceBand(min: 400000, max: 2200000),
    rarity: 5,
    signature: ImageFeatures.signature(
      white: 0.05,
      orange: 0.06,
      yellow: 0.04,
      dark: 0.78,
      gray: 0.28,
      brown: 0.38,
      spots: 0.02,
      sat: 0.18,
    ),
  ),
  Morph(
    id: 'soft-scale',
    nameKo: '소프트스케일',
    nameEn: 'Soft Scale',
    category: MorphCategory.genetic,
    inheritance: Inheritance.incompleteDominant,
    inheritanceKo: '불완전 우성 · 슈퍼폼은 건강 이슈',
    description:
        '비늘이 부드럽고 피부에 가깝게 보이는 불완전 우성입니다. 만졌을 때 매끄럽고, 슈퍼 소프트스케일은 탈피·피부 문제가 보고되어 같은 유전자끼리 교배는 권하지 않습니다.',
    look: '비늘 융기가 낮고 피부가 매끈해 보임',
    assetImage: _asset('normal'),
    aliases: ['소프트스케일', '소프트 스케일', 'softscale', 'soft scale'],
    genes: {GeneKey.softScale: 1},
    price: PriceBand(min: 350000, max: 1800000),
    rarity: 4,
    signature: ImageFeatures.signature(
      white: 0.16,
      orange: 0.2,
      yellow: 0.14,
      dark: 0.36,
      gray: 0.14,
      brown: 0.48,
      spots: 0.02,
      sat: 0.34,
    ),
  ),
  Morph(
    id: 'dunkel',
    nameKo: '던켈',
    nameEn: 'Dunkel',
    category: MorphCategory.genetic,
    inheritance: Inheritance.incompleteDominant,
    inheritanceKo: '불완전 우성 · 카푸치노 계열',
    description:
        '카푸치노 라인에서 나온 매우 어두운 불완전 우성입니다. 에스프레소에 가까운 몸색과 낮은 크레스트가 겹칩니다. 슈퍼폼은 카푸와 비슷하게 건강 이슈가 있어 주의합니다.',
    look: '거의 검은 커피색, 크레스트가 낮음',
    assetImage: _asset('cappuccino'),
    aliases: ['던켈', 'dunkel'],
    genes: {GeneKey.dunkel: 1},
    price: PriceBand(min: 450000, max: 2400000),
    rarity: 5,
    signature: ImageFeatures.signature(
      white: 0.07,
      orange: 0.16,
      yellow: 0.05,
      dark: 0.68,
      gray: 0.12,
      brown: 0.7,
      spots: 0.03,
      sat: 0.24,
    ),
  ),
  Morph(
    id: 'hypo',
    nameKo: '하이포',
    nameEn: 'Hypo',
    category: MorphCategory.genetic,
    inheritance: Inheritance.recessive,
    inheritanceKo: '열성 (멜라닌 감소, 근사)',
    description:
        '멜라닌이 줄어 바탕이 맑고 패턴이 부드럽게 빠집니다. 단일 좌위로 확정되진 않았지만, 브리더들이 열성처럼 추적하는 경우가 많아 헷/비주얼로 계산합니다.',
    look: '연한 바탕, 어두운 무늬가 흐릿함',
    assetImage: _asset('creamsicle'),
    aliases: ['하이포', 'hypo', 'hypomelanistic'],
    genes: {GeneKey.hypo: 2},
    price: PriceBand(min: 180000, max: 700000),
    rarity: 3,
    signature: ImageFeatures.signature(
      white: 0.24,
      orange: 0.38,
      yellow: 0.44,
      dark: 0.08,
      gray: 0.06,
      brown: 0.18,
      spots: 0.03,
      sat: 0.4,
    ),
  ),
  Morph(
    id: 'charcoal',
    nameKo: '차콜',
    nameEn: 'Charcoal',
    category: MorphCategory.genetic,
    inheritance: Inheritance.recessive,
    inheritanceKo: '열성 (어두운 회색 바탕, 근사)',
    description:
        '숯처럼 어두운 회색 바탕입니다. 아잔틱보다 웜톤이 조금 남고, 팬텀보다 패턴이 더 읽힙니다. 열성으로 추적하는 브리더가 많아 헷 차콜을 따로 둡니다.',
    look: '숯회색 바탕, 패턴은 남지만 채도가 낮음',
    assetImage: _asset('phantom'),
    aliases: ['차콜', 'charcoal'],
    genes: {GeneKey.charcoal: 2},
    price: PriceBand(min: 200000, max: 850000),
    rarity: 4,
    signature: ImageFeatures.signature(
      white: 0.1,
      orange: 0.04,
      yellow: 0.04,
      dark: 0.62,
      gray: 0.48,
      brown: 0.2,
      spots: 0.06,
      sat: 0.16,
    ),
  ),
  Morph(
    id: 'lavender',
    nameKo: '라벤더',
    nameEn: 'Lavender',
    category: MorphCategory.color,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 (보라·회보라 발색)',
    description:
        '회색에 보라·라일락 톤이 감도는 발색입니다. 단일 유전자가 아니라 선발로 쌓이며, 아잔틱이나 하이포와 겹치면 더 분명해집니다.',
    look: '회보라·라일락 톤, 채도가 낮음',
    assetImage: _asset('axanthic'),
    aliases: ['라벤더', 'lavender', '라일락'],
    traits: {TraitKey.lavender: 1},
    price: PriceBand(min: 200000, max: 900000),
    rarity: 3,
    signature: ImageFeatures.signature(
      white: 0.2,
      orange: 0.08,
      yellow: 0.06,
      dark: 0.28,
      gray: 0.42,
      brown: 0.16,
      spots: 0.04,
      sat: 0.2,
    ),
  ),
  Morph(
    id: 'chocolate',
    nameKo: '초콜릿',
    nameEn: 'Chocolate',
    category: MorphCategory.color,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 (초콜릿 브라운)',
    description:
        '카카오·밀크초코 같은 따뜻한 갈색 바탕입니다. 카푸치노보다 유전자로 확정되지 않은 발색이라 선발 교배로 진해집니다.',
    look: '따뜻한 초콜릿 브라운, 오렌지 언저리',
    assetImage: _asset('cappuccino'),
    aliases: ['초콜릿', '초코', 'chocolate', 'choc'],
    traits: {TraitKey.chocolate: 1},
    price: PriceBand(min: 150000, max: 600000),
    rarity: 3,
    signature: ImageFeatures.signature(
      white: 0.08,
      orange: 0.32,
      yellow: 0.1,
      dark: 0.42,
      gray: 0.08,
      brown: 0.72,
      spots: 0.04,
      sat: 0.38,
    ),
  ),
  Morph(
    id: 'moonglow',
    nameKo: '문글로우',
    nameEn: 'Moonglow',
    category: MorphCategory.color,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 (고화이트)',
    description:
        '달빛처럼 화이트 커버리지가 넓은 고화이트 표현형입니다. 릴리 화이트와 달리 확정 유전자가 아니라, 선발로 화이트를 쌓은 개체에 붙는 이름입니다.',
    look: '몸 대부분을 덮는 밝은 화이트·크림',
    assetImage: _asset('lilly-white'),
    aliases: ['문글로우', 'moonglow', '문 글로우'],
    traits: {TraitKey.moonglow: 1, TraitKey.harlequin: 0.5},
    price: PriceBand(min: 300000, max: 1500000),
    rarity: 4,
    signature: ImageFeatures.signature(
      white: 0.72,
      orange: 0.1,
      yellow: 0.12,
      dark: 0.06,
      gray: 0.1,
      brown: 0.08,
      spots: 0.02,
      sat: 0.3,
    ),
  ),
  Morph(
    id: 'white-wall',
    nameKo: '화이트월',
    nameEn: 'White Wall',
    category: MorphCategory.pattern,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 (옆구리 화이트)',
    description:
        '옆구리가 하얀 벽처럼 막힌 패턴입니다. 할리퀸 커버리지가 옆구리에 집중된 형태로, 등보다 사이드 화이트가 뚜렷할 때 부릅니다.',
    look: '옆구리를 따라 이어진 넓은 화이트 밴드',
    assetImage: _asset('extreme-harlequin'),
    aliases: ['화이트월', '화이트 월', 'whitewall', 'white wall'],
    traits: {TraitKey.whiteWall: 1, TraitKey.harlequin: 0.75},
    price: PriceBand(min: 220000, max: 950000),
    rarity: 3,
    signature: ImageFeatures.signature(
      white: 0.58,
      orange: 0.16,
      yellow: 0.22,
      dark: 0.18,
      gray: 0.08,
      brown: 0.2,
      spots: 0.04,
      sat: 0.42,
    ),
  ),
  Morph(
    id: 'emptyback',
    nameKo: '엠티백',
    nameEn: 'Emptyback',
    category: MorphCategory.pattern,
    inheritance: Inheritance.polygenic,
    inheritanceKo: '다지성 (등판이 비어 보임)',
    description:
        '등 가운데가 비어 있고 무늬가 가장자리로 밀린 패턴입니다. 익스트림 할리퀸의 한 형태로 보기도 하며, 등판 대비가 클수록 가치가 있습니다.',
    look: '등 중앙은 단색, 가장자리에 밝은 무늬',
    assetImage: _asset('extreme-harlequin'),
    aliases: ['엠티백', '엠프티백', 'emptyback', 'empty back'],
    traits: {TraitKey.emptyback: 1, TraitKey.harlequin: 0.7},
    price: PriceBand(min: 250000, max: 1100000),
    rarity: 4,
    signature: ImageFeatures.signature(
      white: 0.5,
      orange: 0.14,
      yellow: 0.48,
      dark: 0.14,
      gray: 0.06,
      brown: 0.16,
      spots: 0.03,
      sat: 0.46,
    ),
  ),
];

/// Het-only breeding options (`HET_OPTIONS`).
const hetOptions = <HetOption>[
  HetOption(
    id: 'het-axanthic',
    nameKo: '헷 아잔틱',
    genes: {GeneKey.axanthic: 1},
    aliases: ['헷아잔틱', 'hetaxanthic', 'hetax'],
  ),
  HetOption(
    id: 'het-phantom',
    nameKo: '헷 팬텀',
    genes: {GeneKey.phantom: 1},
    aliases: ['헷팬텀', 'hetphantom'],
  ),
  HetOption(
    id: 'het-hypo',
    nameKo: '헷 하이포',
    genes: {GeneKey.hypo: 1},
    aliases: ['헷하이포', 'hethypo'],
  ),
  HetOption(
    id: 'het-charcoal',
    nameKo: '헷 차콜',
    genes: {GeneKey.charcoal: 1},
    aliases: ['헷차콜', 'hetcharcoal'],
  ),
  HetOption(
    id: 'het-sable',
    nameKo: '헷 세이블',
    genes: {GeneKey.sable: 1},
    aliases: ['헷세이블', 'hetsable'],
  ),
  HetOption(
    id: 'het-lilly',
    nameKo: '헷 릴리',
    genes: {GeneKey.lillyWhite: 1},
    aliases: ['헷릴리', '헷릴리화이트', 'hetlilly', 'hetlily'],
  ),
  HetOption(
    id: 'het-dunkel',
    nameKo: '헷 던켈',
    genes: {GeneKey.dunkel: 1},
    aliases: ['헷던켈', 'hetdunkel'],
  ),
];

final Map<String, Morph> _byId = {for (final m in morphCatalog) m.id: m};

Morph? getMorph(String? id) => id == null ? null : _byId[id];

/// Morphs that can be picked as a breeding parent or shown in the gallery — the
/// het-only pseudo entries are excluded, matching `category !== "het"` filters.
final List<Morph> selectableMorphs = morphCatalog
    .where((m) => m.category != MorphCategory.het)
    .toList();

/// Bundled image path for a morph id, with a graceful fallback for ids that only
/// exist as phenotype labels. Mirrors `imagePath()` in `js/engine.js`.
String morphImagePath(String id) => getMorph(id)?.assetImage ?? _asset(id);

/// Lowercases and strips whitespace/dashes so aliases match loosely.
/// Ported from `normalize()` in `js/morphs.js`.
String normalizeName(String input) => input
    .toLowerCase()
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll(RegExp(r'[-_]'), '');

/// An alias paired with the morph it points at.
class AliasEntry {
  const AliasEntry(this.alias, this.morph);

  final String alias;
  final Morph morph;
}

Morph _hetPseudoMorph(HetOption option) => Morph(
  id: option.id,
  nameKo: option.nameKo,
  nameEn: option.id,
  category: MorphCategory.het,
  inheritance: Inheritance.recessive,
  inheritanceKo: '헷 (보인자)',
  description: '겉으로는 드러나지 않지만 유전자를 하나 가지고 있는 개체입니다.',
  look: '외형은 일반 개체와 같음',
  assetImage: _asset('normal'),
  aliases: option.aliases,
  genes: option.genes,
  price: const PriceBand(min: 80000, max: 400000),
);

/// Every alias in the catalog, longest first so that "릴리아잔틱" wins over "릴리".
/// Ported from `allAliases()` in `js/morphs.js`.
final List<AliasEntry> allAliases = () {
  final rows = <AliasEntry>[];
  for (final morph in morphCatalog) {
    for (final alias in morph.aliases) {
      rows.add(AliasEntry(normalizeName(alias), morph));
    }
  }
  for (final option in hetOptions) {
    final pseudo = _hetPseudoMorph(option);
    for (final alias in [
      ...option.aliases,
      option.nameKo.replaceAll(RegExp(r'\s'), ''),
    ]) {
      rows.add(AliasEntry(normalizeName(alias), pseudo));
    }
  }
  rows.sort((a, b) => b.alias.length.compareTo(a.alias.length));
  return rows;
}();

/// Finds a catalog morph whose Korean name, English name or alias matches
/// [name]. Ported from `matchMorphByName()` in `js/library.js`.
///
/// Exact matches win first. Otherwise the longest alias contained in [name]
/// is used, so 「릴리화이트 수컷」 still attaches to Lilly White instead of
/// becoming a separate community morph.
Morph? matchMorphByName(String name) {
  final needle = normalizeName(name);
  if (needle.isEmpty) return null;
  for (final morph in morphCatalog) {
    if (morph.category == MorphCategory.het) continue;
    final keys = [
      morph.nameKo,
      morph.nameEn,
      ...morph.aliases,
    ].map(normalizeName).toSet();
    if (keys.contains(needle)) return morph;
  }
  for (final entry in allAliases) {
    if (entry.morph.category == MorphCategory.het) continue;
    if (entry.alias.length < 2) continue;
    if (needle.contains(entry.alias)) return entry.morph;
  }
  return null;
}

/// Catalog morphs whose name or alias overlaps [query], for the reference
/// photo form's type suggestions.
List<Morph> suggestCatalogMorphs(String query, {int limit = 6}) {
  final needle = normalizeName(query);
  if (needle.isEmpty) return const [];
  final hits = <Morph>[];
  for (final morph in selectableMorphs) {
    final keys = [
      morph.nameKo,
      morph.nameEn,
      ...morph.aliases,
    ].map(normalizeName);
    if (keys.any((key) => key.contains(needle) || needle.contains(key))) {
      hits.add(morph);
      if (hits.length >= limit) break;
    }
  }
  return hits;
}

/// Stable id for a community photo's morph: the catalog id when the name is
/// recognised, otherwise a `user-` prefixed slug.
/// Ported from `userMorphId()` in `js/library.js`.
String userMorphId(String name) {
  final linked = matchMorphByName(name);
  if (linked != null) return linked.id;
  final slug = normalizeName(name).replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');
  return 'user-${slug.substring(0, slug.length.clamp(0, 40))}';
}
