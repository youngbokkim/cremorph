import 'package:crehooni/data/morph_catalog.dart';
import 'package:crehooni/domain/morph_nlp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('findMorphs', () {
    test('picks up two morphs from a natural Korean question', () {
      final found = MorphNlp.findMorphs('릴리화이트랑 아잔틱 섞으면?');
      expect(found.map((m) => m.id), ['lilly-white', 'axanthic']);
    });

    test('prefers the longest alias so 릴리아잔틱 is not read as 릴리 + 아잔틱', () {
      final found = MorphNlp.findMorphs('릴잔틱 어때?');
      expect(found.map((m) => m.id), ['lilly-axanthic']);
    });

    test('matches English aliases', () {
      final found = MorphNlp.findMorphs('cappuccino x lilly');
      expect(
        found.map((m) => m.id),
        containsAll(['cappuccino', 'lilly-white']),
      );
    });

    test('ignores spacing and dashes', () {
      expect(MorphNlp.findMorphs('익스트림 할리퀸').map((m) => m.id), [
        'extreme-harlequin',
      ]);
    });

    test('returns nothing for unrelated text', () {
      expect(MorphNlp.findMorphs('오늘 날씨 어때?'), isEmpty);
    });

    test('recognises het options', () {
      expect(MorphNlp.findMorphs('헷아잔틱').map((m) => m.id), ['het-axanthic']);
    });
  });

  group('answer', () {
    test('two morphs produce a breeding result', () {
      final answer = MorphNlp.answer('카푸치노랑 릴리 섞으면 뭐가 나와?');
      expect(answer.kind, AnswerKind.breed);
      expect(answer.result, isNotNull);
      expect(
        answer.result!.geneOutcomes.any((o) => o.name.contains('프라푸치노')),
        isTrue,
      );
    });

    test('a single morph with 끼리 is treated as a self-cross', () {
      final answer = MorphNlp.answer('릴리끼리 교배하면?');
      expect(answer.kind, AnswerKind.breed);
      expect(answer.morphs.map((m) => m.id), ['lilly-white', 'lilly-white']);
      expect(answer.result!.warnings, isNotEmpty);
    });

    test('a repeated morph name is treated as a self-cross', () {
      final answer = MorphNlp.answer('할리퀸 할리퀸');
      expect(answer.kind, AnswerKind.breed);
      expect(answer.morphs, hasLength(2));
    });

    test('a single morph without a breeding cue returns info', () {
      final answer = MorphNlp.answer('팬텀은 어떤 모프야?');
      expect(answer.kind, AnswerKind.info);
      expect(answer.morph!.id, 'phantom');
    });

    test('unrecognised text returns help with guidance', () {
      final answer = MorphNlp.answer('안녕하세요');
      expect(answer.kind, AnswerKind.help);
      expect(answer.message, contains('모프 이름을 두 개'));
    });

    test('empty input returns help', () {
      expect(MorphNlp.answer('   ').kind, AnswerKind.help);
    });

    test('every suggestion chip yields an actionable answer', () {
      for (final chip in MorphNlp.suggestions) {
        expect(
          MorphNlp.answer(chip).kind,
          isNot(AnswerKind.help),
          reason: chip,
        );
      }
    });
  });

  group('name matching', () {
    test('matchMorphByName resolves Korean, English and aliases', () {
      expect(matchMorphByName('릴리 화이트')?.id, 'lilly-white');
      expect(matchMorphByName('Lilly White')?.id, 'lilly-white');
      expect(matchMorphByName('릴리')?.id, 'lilly-white');
      expect(matchMorphByName('릴리화이트 수컷')?.id, 'lilly-white');
      expect(matchMorphByName('우리집 할로윈')?.id, 'halloween');
      expect(matchMorphByName('없는모프'), isNull);
    });

    test('userMorphId links known names and slugs unknown ones', () {
      expect(userMorphId('할로윈'), 'halloween');
      expect(userMorphId('내가 키우는 애'), startsWith('user-'));
    });
  });
}
