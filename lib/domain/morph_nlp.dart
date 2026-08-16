import '../data/models/breeding.dart';
import '../data/models/morph.dart';
import '../data/morph_catalog.dart';
import 'genetics.dart';

/// What the user's question turned out to be asking for.
enum AnswerKind { breed, info, help }

/// Parsed answer to a free-text Korean question.
class MorphAnswer {
  const MorphAnswer.breed({required this.morphs, required this.result})
    : kind = AnswerKind.breed,
      morph = null,
      message = null;

  const MorphAnswer.info(Morph this.morph)
    : kind = AnswerKind.info,
      morphs = const [],
      result = null,
      message = null;

  const MorphAnswer.help([this.message])
    : kind = AnswerKind.help,
      morphs = const [],
      result = null,
      morph = null;

  final AnswerKind kind;

  /// The two parents, for [AnswerKind.breed].
  final List<Morph> morphs;
  final BreedingResult? result;

  /// The single morph asked about, for [AnswerKind.info].
  final Morph? morph;

  /// Fallback guidance, for [AnswerKind.help].
  final String? message;
}

/// Rule-based Korean question understanding, ported from `js/engine.js`.
///
/// This is deliberately not an LLM: it scans the text for known morph aliases
/// and decides whether the user is asking about a cross or a single morph.
abstract final class MorphNlp {
  static final _breedCue = RegExp(
    r'섞|교배|믹스|mix|×|\bx\b|이랑|랑|와 |붙이|메이팅|브리딩|확률|나오면|끼리',
  );
  static final _selfCrossCue = RegExp(r'끼리|같은모프|두마리');

  /// Extracts the morphs mentioned in [text], longest alias first and without
  /// letting two matches overlap. Ported from `findMorphsInText()`.
  static List<Morph> findMorphs(String text) {
    final compact = normalizeName(text);
    if (compact.isEmpty) return const [];

    final claimed = List<bool>.filled(compact.length, false);
    final found = <Morph>[];

    for (final entry in allAliases) {
      final alias = entry.alias;
      if (alias.length < 2) continue;
      var idx = compact.indexOf(alias);
      while (idx != -1) {
        final overlaps = claimed
            .sublist(idx, idx + alias.length)
            .any((taken) => taken);
        if (!overlaps) {
          for (var i = idx; i < idx + alias.length; i++) {
            claimed[i] = true;
          }
          if (!found.any((m) => m.id == entry.morph.id)) {
            found.add(entry.morph);
          }
        }
        idx = compact.indexOf(alias, idx + 1);
      }
    }
    return found;
  }

  /// How many times any alias of [morph] appears — used to detect "릴리랑 릴리"
  /// style self-crosses. Ported from `aliasHitCount()`.
  static int aliasHitCount(String text, Morph morph) {
    final compact = normalizeName(text);
    var hits = 0;
    for (final raw in morph.aliases) {
      final alias = normalizeName(raw);
      if (alias.length < 2) continue;
      var idx = compact.indexOf(alias);
      while (idx != -1) {
        hits += 1;
        idx = compact.indexOf(alias, idx + alias.length);
      }
    }
    return hits;
  }

  /// Ported from `answerQuestion()`.
  static MorphAnswer answer(String text) {
    final raw = text.trim();
    if (raw.isEmpty) return const MorphAnswer.help();

    final morphs = findMorphs(raw);
    final hasBreedCue = _breedCue.hasMatch(raw);
    final isSelfCross =
        _selfCrossCue.hasMatch(normalizeName(raw)) ||
        (morphs.length == 1 && aliasHitCount(raw, morphs.first) >= 2);

    if (morphs.length >= 2) {
      return MorphAnswer.breed(
        morphs: [morphs[0], morphs[1]],
        result: Genetics.breed(profileFor(morphs[0]), profileFor(morphs[1])),
      );
    }

    if (morphs.length == 1 &&
        (isSelfCross || (hasBreedCue && raw.contains('끼리')))) {
      final only = morphs.first;
      return MorphAnswer.breed(
        morphs: [only, only],
        result: Genetics.breed(profileFor(only), profileFor(only)),
      );
    }

    if (morphs.length == 1) return MorphAnswer.info(morphs.first);

    return const MorphAnswer.help(
      '모프 이름을 두 개 넣어 보세요. 예: 「릴리화이트랑 아잔틱 섞으면?」「카푸치노 x 릴리」「할리퀸이랑 핀스트라이프」',
    );
  }

  /// Suggestion chips shown above the chat.
  static const suggestions = <String>[
    '릴리화이트랑 아잔틱 섞으면?',
    '카푸치노 x 릴리 화이트',
    '할리퀸이랑 핀스트라이프',
    '릴리끼리 교배하면?',
    '팬텀은 어떤 모프야?',
  ];
}
