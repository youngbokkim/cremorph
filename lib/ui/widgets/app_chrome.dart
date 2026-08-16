import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// The layered radial gradients from the `body` rule in `css/app.css`.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.soil),
      child: Stack(
        fit: StackFit.expand,
        children: [const _GlowLayer(), const GrainOverlay(), child],
      ),
    );
  }
}

class _GlowLayer extends StatelessWidget {
  const _GlowLayer();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // radial-gradient(1200px 600px at 10% -10%, #2a3a22 ...)
          Align(
            alignment: const Alignment(-0.8, -1.2),
            child: _Glow(color: AppColors.glowGreen, width: 1200, height: 600),
          ),
          // radial-gradient(900px 500px at 110% 10%, #3a2214 ...)
          Align(
            alignment: const Alignment(1.2, -0.8),
            child: _Glow(color: AppColors.glowRust, width: 900, height: 500),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.width, required this.height});

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0, 0.55],
          ),
        ),
      ),
    );
  }
}

/// Recreates the `.grain` fractal-noise film at 7% opacity.
///
/// The web version used an inline SVG `feTurbulence` filter. Flutter has no
/// equivalent, so a fixed pseudo-random dot field is painted instead — the
/// intent is the same subtle paper texture over the flat background.
class GrainOverlay extends StatelessWidget {
  const GrainOverlay({this.opacity = 0.07, super.key});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(painter: _GrainPainter(), size: Size.infinite),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  /// Fixed seed keeps the texture stable across rebuilds, so it reads as a
  /// material rather than animated static.
  static const _tileSize = 180.0;
  static final _offsets = _buildTile();

  static List<Offset> _buildTile() {
    final random = math.Random(20260814);
    return List.generate(
      1400,
      (_) => Offset(
        random.nextDouble() * _tileSize,
        random.nextDouble() * _tileSize,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.cream;
    final tilesX = (size.width / _tileSize).ceil();
    final tilesY = (size.height / _tileSize).ceil();

    for (var ty = 0; ty < tilesY; ty++) {
      for (var tx = 0; tx < tilesX; tx++) {
        final origin = Offset(tx * _tileSize, ty * _tileSize);
        for (final offset in _offsets) {
          canvas.drawRect(
            Rect.fromLTWH(origin.dx + offset.dx, origin.dy + offset.dy, 1, 1),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => false;
}

/// The CSS-only gecko crest logo from `.crest`, redrawn with a painter.
class CrestLogo extends StatelessWidget {
  const CrestLogo({this.size = 58, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CrestPainter()),
    );
  }
}

class _CrestPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 58;
    final head = Rect.fromLTWH(0, 0, size.width, size.height);

    // The two horns behind the head (`.crest::before` / `::after`).
    final hornPaint = Paint()..color = const Color(0xFFE8C56A);
    for (final (dx, angle) in [(12.0, -18.0), (36.0, 18.0)]) {
      canvas.save();
      final hornRect = Rect.fromLTWH(
        dx * scale,
        -7 * scale,
        10 * scale,
        16 * scale,
      );
      canvas.translate(hornRect.center.dx, hornRect.center.dy);
      canvas.rotate(angle * math.pi / 180);
      canvas.translate(-hornRect.center.dx, -hornRect.center.dy);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          hornRect,
          topLeft: Radius.circular(8 * scale),
          topRight: Radius.circular(8 * scale),
          bottomLeft: Radius.circular(2 * scale),
          bottomRight: Radius.circular(2 * scale),
        ),
        hornPaint,
      );
      canvas.restore();
    }

    // Head: linear-gradient(180deg, #c45a32, #7a3a1c).
    final headShape = RRect.fromRectAndCorners(
      head,
      topLeft: Radius.circular(18 * scale),
      topRight: Radius.circular(18 * scale),
      bottomLeft: Radius.circular(22 * scale),
      bottomRight: Radius.circular(22 * scale),
    );
    canvas.drawRRect(
      headShape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFC45A32), Color(0xFF7A3A1C)],
        ).createShader(head),
    );

    // Inner bottom shadow: inset 0 -8px 0 rgba(0,0,0,.18).
    canvas.save();
    canvas.clipRRect(headShape);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 8 * scale, size.width, 8 * scale),
      Paint()..color = const Color(0x2E000000),
    );
    canvas.restore();

    // Eyes and the amber crown dot.
    canvas.drawCircle(
      Offset(size.width * 0.32, size.height * 0.40),
      5 * scale,
      Paint()..color = const Color(0xFF1A140C),
    );
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.40),
      5 * scale,
      Paint()..color = const Color(0xFF1A140C),
    );
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.38),
      8 * scale,
      Paint()..color = const Color(0xFFE8C56A).withValues(alpha: 0.55),
    );

    // Hairline highlight: 0 0 0 1px rgba(255,220,160,.2).
    canvas.drawRRect(
      headShape.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x33FFDCA0),
    );
  }

  @override
  bool shouldRepaint(_CrestPainter oldDelegate) => false;
}
