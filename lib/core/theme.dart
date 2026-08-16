import 'package:flutter/material.dart';

/// Design tokens ported 1:1 from the original `css/app.css` `:root` block so the
/// Flutter app keeps the exact soil/moss palette of the web version.
abstract final class AppColors {
  static const soil = Color(0xFF100C08);
  static const moss = Color(0xFF172018);
  static const bark = Color(0xFF2A1C12);
  static const leaf = Color(0xFF4A6A3E);
  static const lichen = Color(0xFFD5E3A8);
  static const cream = Color(0xFFF4EBD4);
  static const paper = Color(0xFFEFE4CC);
  static const ink = Color(0xFF16110C);
  static const muted = Color(0xFFB7C2A8);
  static const amber = Color(0xFFE3923A);
  static const ember = Color(0xFFC45A32);
  static const eye = Color(0xFFC6E25C);
  static const danger = Color(0xFFE25B4A);
  static const ok = Color(0xFF7CB87A);

  /// `--line: rgba(244, 235, 212, 0.12)`
  static const line = Color(0x1FF4EBD4);

  /// Button label colour on amber fills.
  static const onAmber = Color(0xFF1A1208);

  /// Card gradient from `.card`.
  static const cardTop = Color(0x0AFFFFFF);
  static const cardBottom = Color(0x05FFFFFF);

  /// Backdrop radial gradient stops from `body`.
  static const glowGreen = Color(0xFF2A3A22);
  static const glowRust = Color(0xFF3A2214);

  static const modalScrim = Color(0xB8080604);
  static const modalCard = Color(0xFF1A1611);

  /// `.g-card.custom` — community-contributed gallery cards.
  static const paperCustom = Color(0xFFE8D9B8);
}

abstract final class AppRadius {
  static const card = 22.0;
  static const drop = 18.0;
  static const button = 12.0;
  static const chip = 999.0;
  static const thumb = 8.0;
  static const tile = 16.0;
}

abstract final class AppSpacing {
  static const gutter = 22.0;
  static const cardPad = 22.0;
  static const maxContentWidth = 1180.0;

  /// The `@media (max-width: 860px)` breakpoint the web layout collapses at.
  static const compactBreakpoint = 860.0;
}

abstract final class AppFonts {
  /// Display / numeric face — `"Fraunces", "Times New Roman", serif`.
  static const display = 'Fraunces';

  /// Body face — `"Pretendard", "Noto Sans KR", "Apple SD Gothic Neo"`.
  static const body = 'Pretendard';

  static const koreanFallback = <String>[
    'Apple SD Gothic Neo',
    'Noto Sans KR',
    'Malgun Gothic',
  ];
}

abstract final class AppShadows {
  /// `--shadow: 0 24px 60px rgba(0, 0, 0, 0.45)`
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x73000000), blurRadius: 60, offset: Offset(0, 24)),
  ];
}

/// Text styles named after the CSS classes they replace.
abstract final class AppText {
  static const _body = TextStyle(
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.koreanFallback,
    letterSpacing: -0.14,
    color: AppColors.cream,
  );

  /// Fraunces ships as a variable font, so the `wght` axis has to be set
  /// explicitly — `fontWeight` alone would render every size at the default
  /// weight.
  static TextStyle _displayAt(double weight) => TextStyle(
    fontFamily: AppFonts.display,
    fontFamilyFallback: AppFonts.koreanFallback,
    color: AppColors.cream,
    fontVariations: [FontVariation('wght', weight)],
  );

  /// `.brand h1`
  static final brand = _displayAt(
    600,
  ).copyWith(fontSize: 30, letterSpacing: 2.4, height: 1);

  /// `.latin`
  static final latin = _displayAt(
    500,
  ).copyWith(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.muted);

  /// `.card h2`
  static final cardTitle = _body.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  /// `.card .sub`
  static final sub = _body.copyWith(
    fontSize: 13,
    height: 1.55,
    color: AppColors.muted,
  );

  /// `.hero-note`
  static final heroNote = _body.copyWith(
    fontSize: 15,
    height: 1.7,
    color: AppColors.muted,
  );

  /// `.kicker`
  static final kicker = _body.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.76,
    color: AppColors.ember,
  );

  /// `.morph-hero h3`
  static final morphName = _displayAt(
    650,
  ).copyWith(fontSize: 22, color: AppColors.ink, height: 1.2);

  /// `.en`
  static final en = _body.copyWith(fontSize: 12, color: AppColors.muted);

  /// `.pct` / `.price` — Fraunces numerals.
  static final percent = _displayAt(
    650,
  ).copyWith(fontSize: 22, color: AppColors.lichen);

  static final price = _displayAt(
    650,
  ).copyWith(fontSize: 28, color: AppColors.lichen);

  /// `.badge`
  static final badge = _body.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.ember,
  );

  /// `.bubble`
  static final bubble = _body.copyWith(fontSize: 14, height: 1.55);

  /// `.btn`
  static final button = _body.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.onAmber,
  );

  /// `.tab`
  static final tab = _body.copyWith(fontSize: 13.5);

  /// `.foot`
  static final foot = _body.copyWith(
    fontSize: 12,
    height: 1.6,
    color: AppColors.muted,
  );

  static final body = _body.copyWith(fontSize: 14, height: 1.5);
  static final bodySmall = _body.copyWith(fontSize: 13, height: 1.5);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.amber,
    onPrimary: AppColors.onAmber,
    secondary: AppColors.lichen,
    onSecondary: AppColors.ink,
    surface: AppColors.soil,
    onSurface: AppColors.cream,
    error: AppColors.danger,
    onError: AppColors.cream,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.soil,
    fontFamily: AppFonts.body,
    fontFamilyFallback: AppFonts.koreanFallback,
    splashFactory: InkSparkle.splashFactory,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.amber,
      selectionColor: Color(0x55E3923A),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.line,
      thickness: 1,
      space: 1,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.modalCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      textStyle: AppText.bodySmall,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.modalCard,
      contentTextStyle: AppText.bodySmall,
      actionTextColor: AppColors.amber,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.amber,
      linearTrackColor: Color(0x14FFFFFF),
    ),
  );
}
