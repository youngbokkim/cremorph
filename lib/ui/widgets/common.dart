import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/morph.dart';

/// The `.card` surface: subtle top-down white wash, hairline border, deep shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPad),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.cardTop, AppColors.cardBottom],
        ),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: AppShadows.card,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Card with the `h2` + `.sub` header the web version repeats on every panel.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: AppText.cardTitle)),
              ?trailing,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: AppText.sub),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// The `.btn` primary button — full width, amber, dark label.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: AppColors.amber,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: SizedBox.square(
                      dimension: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onAmber,
                      ),
                    ),
                  )
                else if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(icon, size: 18, color: AppColors.onAmber),
                  ),
                Text(label, style: AppText.button),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The `.btn.ghost` variant — transparent with a hairline border.
class GhostButton extends StatelessWidget {
  const GhostButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.dense = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.4 : 1,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Padding(
            padding: dense
                ? const EdgeInsets.symmetric(vertical: 8, horizontal: 12)
                : const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(icon, size: 16, color: AppColors.cream),
                  ),
                Text(
                  label,
                  style: dense
                      ? AppText.bodySmall.copyWith(fontSize: 12)
                      : AppText.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The `.badge` pill.
class AppBadge extends StatelessWidget {
  const AppBadge(this.label, {this.color, super.key});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.ember;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(label, style: AppText.badge.copyWith(color: tint)),
      ),
    );
  }
}

/// The `.kicker` uppercase label.
class Kicker extends StatelessWidget {
  const Kicker(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Text(label.toUpperCase(), style: AppText.kicker);
}

/// The `.bar` confidence meter with its amber→lime gradient fill.
class ConfidenceBar extends StatelessWidget {
  const ConfidenceBar({required this.value, super.key});

  /// 0–1.
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            const ColoredBox(color: Color(0x14FFFFFF)),
            FractionallySizedBox(
              widthFactor: value.clamp(0, 1),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.amber, AppColors.eye],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The `.warn` / `.danger-box` callouts.
class Callout extends StatelessWidget {
  const Callout({
    required this.title,
    required this.text,
    this.isDanger = false,
    super.key,
  });

  final String title;
  final String text;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final tint = isDanger ? AppColors.danger : AppColors.amber;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        border: Border.all(
          color: tint.withValues(alpha: isDanger ? 0.4 : 0.35),
        ),
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 10, top: 1),
            child: Icon(
              isDanger ? Icons.warning_amber_rounded : Icons.info_outline,
              size: 18,
              color: isDanger ? const Color(0xFFFFC4BC) : tint,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDanger ? const Color(0xFFFFC4BC) : AppColors.cream,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: AppText.bodySmall.copyWith(
                    color: isDanger
                        ? const Color(0xFFFFC4BC)
                        : AppColors.cream.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The `.analyzing` row: a blinking lime dot plus status text.
class AnalyzingIndicator extends StatefulWidget {
  const AnalyzingIndicator({required this.message, super.key});

  final String message;

  @override
  State<AnalyzingIndicator> createState() => _AnalyzingIndicatorState();
}

class _AnalyzingIndicatorState extends State<AnalyzingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 1, end: 0.2).animate(_controller),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.eye,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(dimension: 8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.message,
              style: AppText.bodySmall.copyWith(color: AppColors.lichen),
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays a morph photo whether it is a bundled asset or a remote URL.
class MorphImage extends StatelessWidget {
  const MorphImage({required this.morph, this.fit = BoxFit.cover, super.key})
    : path = null;

  /// For an explicit asset path or URL, e.g. a community photo.
  const MorphImage.path(this.path, {this.fit = BoxFit.cover, super.key})
    : morph = null;

  final Morph? morph;
  final String? path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final source = path ?? morph?.primaryImage;
    if (source == null) return const _ImagePlaceholder();

    if (source.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: source,
        fit: fit,
        placeholder: (_, _) => const _ImagePlaceholder(),
        errorWidget: (_, _, _) => const _ImagePlaceholder(),
      );
    }
    return Image.asset(
      source,
      fit: fit,
      errorBuilder: (_, _, _) => const _ImagePlaceholder(),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.bark,
      child: Center(child: Icon(Icons.pets, color: AppColors.muted, size: 20)),
    );
  }
}

/// Constrains content to 1180px and centres it, like the `.app` wrapper.
class ContentWidth extends StatelessWidget {
  const ContentWidth({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSpacing.maxContentWidth),
        child: child,
      ),
    );
  }
}

/// True below the 860px breakpoint where the web layout stacks its columns.
bool isCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < AppSpacing.compactBreakpoint;

/// Two columns side by side above the breakpoint, stacked below — the Flutter
/// equivalent of `.grid-2`.
class ResponsiveTwoColumn extends StatelessWidget {
  const ResponsiveTwoColumn({
    required this.left,
    required this.right,
    this.gap = AppSpacing.gutter,
    super.key,
  });

  final Widget left;
  final Widget right;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (isCompact(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          SizedBox(height: gap),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        SizedBox(width: gap),
        Expanded(child: right),
      ],
    );
  }
}
