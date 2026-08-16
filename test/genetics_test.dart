import 'package:crehooni/data/models/breeding.dart';
import 'package:crehooni/data/morph_catalog.dart';
import 'package:crehooni/domain/genetics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds an outcome by exact phenotype name.
OffspringOutcome? outcomeNamed(BreedingResult r, String name) =>
    r.geneOutcomes.where((o) => o.name == name).firstOrNull;

void main() {
  group('punnett', () {
    test('het × het gives the classic 1:2:1 split', () {
      final rows = Genetics.punnett(1, 1);
      expect(rows.map((r) => r.copies), [0, 1, 2]);
      expect(rows.map((r) => r.p), [0.25, 0.5, 0.25]);
    });

    test('visual recessive × no copies gives all hets', () {
      final rows = Genetics.punnett(2, 0);
      expect(rows.length, 1);
      expect(rows.single.copies, 1);
      expect(rows.single.p, 1.0);
    });

    test('visual × visual is fully visual', () {
      final rows = Genetics.punnett(2, 2);
      expect(rows.single.copies, 2);
      expect(rows.single.p, 1.0);
    });
  });

  group('lilly white lethality', () {
    final lilly = getMorph('lilly-white')!;
    final result = Genetics.breed(
      BreedingProfile.fromMorph(lilly),
      BreedingProfile.fromMorph(lilly),
    );

    test('produces 25% super lilly white and flags it lethal', () {
      final superLilly = outcomeNamed(result, '슈퍼 릴리 화이트');
      expect(superLilly, isNotNull);
      expect(superLilly!.percent, 25);
      expect(superLilly.lethal, isTrue);
    });

    test('raises a danger-level warning', () {
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single.level, WarningLevel.danger);
    });

    test('outcomes sum to 100%', () {
      final total = result.geneOutcomes.fold<double>(
        0,
        (s, o) => s + o.percent,
      );
      expect(total, closeTo(100, 0.05));
    });
  });

  group('cappuccino × cappuccino', () {
    final capp = getMorph('cappuccino')!;
    final result = Genetics.breed(
      BreedingProfile.fromMorph(capp),
      BreedingProfile.fromMorph(capp),
    );

    test('produces 25% super cappuccino with a caution flag', () {
      final superCapp = outcomeNamed(result, '슈퍼 카푸치노');
      expect(superCapp, isNotNull);
      expect(superCapp!.percent, 25);
      expect(superCapp.caution, isTrue);
      expect(superCapp.lethal, isFalse);
    });

    test('warns at the lower "warn" level, not "danger"', () {
      expect(result.warnings.single.level, WarningLevel.warn);
    });
  });

  test('lilly × cappuccino yields 25% frappuccino', () {
    final result = Genetics.breed(
      BreedingProfile.fromMorph(getMorph('lilly-white')!),
      BreedingProfile.fromMorph(getMorph('cappuccino')!),
    );
    expect(outcomeNamed(result, '프라푸치노')?.percent, 25);
    expect(result.warnings, isEmpty);
  });

  test('visual axanthic × normal produces 100% het axanthic', () {
    final result = Genetics.breed(
      BreedingProfile.fromMorph(getMorph('axanthic')!),
      BreedingProfile.fromMorph(getMorph('normal')!),
    );
    expect(result.geneOutcomes, hasLength(1));
    expect(result.geneOutcomes.single.name, contains('100% het 아잔틱'));
    expect(result.geneOutcomes.single.percent, 100);
  });

  test('sable × sable splits like other incomplete dominants', () {
    final sable = getMorph('sable')!;
    final result = Genetics.breed(
      BreedingProfile.fromMorph(sable),
      BreedingProfile.fromMorph(sable),
    );
    expect(outcomeNamed(result, '슈퍼 세이블')?.percent, 25);
    expect(outcomeNamed(result, '세이블')?.percent, 50);
  });

  test('het hypo × het hypo gives 25% visual hypo', () {
    final het = BreedingProfile.empty().withHet(GeneKey.hypo);
    final result = Genetics.breed(het, het);
    expect(outcomeNamed(result, '하이포')?.percent, 25);
    expect(outcomeNamed(result, '노멀 (유전자 비발현)')?.percent, 25);
  });

  test('het axanthic × het axanthic gives 25% visual axanthic', () {
    final het = BreedingProfile.empty().withHet(GeneKey.axanthic);
    final result = Genetics.breed(het, het);
    expect(outcomeNamed(result, '아잔틱')?.percent, 25);
    expect(outcomeNamed(result, '노멀 (유전자 비발현)')?.percent, 25);
  });

  test('normal × normal has no confirmed genes to split', () {
    final result = Genetics.breed(
      BreedingProfile.fromMorph(getMorph('normal')!),
      BreedingProfile.fromMorph(getMorph('normal')!),
    );
    expect(result.geneOutcomes.single.percent, 100);
    expect(result.warnings, isEmpty);
  });

  group('pattern forecast', () {
    test('harlequin × harlequin favours harlequin offspring', () {
      final harley = BreedingProfile.fromMorph(getMorph('harlequin')!);
      final rows = Genetics.patternForecast(harley, harley);
      expect(rows.first.name, '할리퀸');
      expect(rows.first.percent, 55);
    });

    test('two extreme harlequins shift toward extreme', () {
      final extreme = BreedingProfile.fromMorph(getMorph('extreme-harlequin')!);
      final rows = Genetics.patternForecast(extreme, extreme);
      expect(rows.any((r) => r.name == '익스트림 할리퀸'), isTrue);
    });

    test('pinstripe on one side still shows up around half the time', () {
      final rows = Genetics.patternForecast(
        BreedingProfile.fromMorph(getMorph('pinstripe')!),
        BreedingProfile.fromMorph(getMorph('normal')!),
      );
      expect(rows.firstWhere((r) => r.name == '핀스트라이프').percent, 52);
    });

    test('two morphs with no patterns forecast nothing', () {
      final normal = BreedingProfile.fromMorph(getMorph('normal')!);
      expect(Genetics.patternForecast(normal, normal), isEmpty);
    });
  });

  group('withHet', () {
    test('adds a single copy and relabels', () {
      final profile = BreedingProfile.fromMorph(
        getMorph('harlequin')!,
      ).withHet(GeneKey.phantom);
      expect(profile.gene(GeneKey.phantom), 1);
      expect(profile.label, contains('헷 팬텀'));
    });

    test('does not downgrade an existing visual', () {
      final profile = BreedingProfile.fromMorph(
        getMorph('axanthic')!,
      ).withHet(GeneKey.axanthic);
      expect(profile.gene(GeneKey.axanthic), 2);
    });
  });

  test('every gene outcome maps to a resolvable image', () {
    for (final a in selectableMorphs) {
      for (final b in selectableMorphs) {
        final result = Genetics.breed(
          BreedingProfile.fromMorph(a),
          BreedingProfile.fromMorph(b),
        );
        for (final outcome in result.geneOutcomes) {
          expect(
            outcome.imagePath,
            startsWith('assets/morphs/'),
            reason: '${a.id} × ${b.id} → ${outcome.name}',
          );
        }
        final total = result.geneOutcomes.fold<double>(
          0,
          (s, o) => s + o.percent,
        );
        expect(total, closeTo(100, 0.2), reason: '${a.id} × ${b.id}');
      }
    }
  });
}
