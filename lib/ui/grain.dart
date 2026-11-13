import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A tiling film-grain texture, generated once per app run.
class GrainTexture {
  static ui.Image? image;
  static Future<ui.Image>? _future;

  static Future<ui.Image> load() => _future ??= _make();

  static Future<ui.Image> _make() {
    const size = 160;
    final rnd = Random(11);
    final px = Uint8List(size * size * 4);
    for (var i = 0; i < size * size; i++) {
      final v = rnd.nextInt(256);
      px[i * 4] = v;
      px[i * 4 + 1] = v;
      px[i * 4 + 2] = v;
      px[i * 4 + 3] = 255;
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(px, size, size, ui.PixelFormat.rgba8888, (img) {
      image = img;
      done.complete(img);
    });
    return done.future;
  }
}

/// Paints grain over whatever is below it. Use inside a Stack over gradients.
class GrainOverlay extends StatefulWidget {
  const GrainOverlay({super.key, this.opacity = 0.55, this.blendMode = BlendMode.overlay});

  final double opacity;
  final BlendMode blendMode;

  @override
  State<GrainOverlay> createState() => _GrainOverlayState();
}

class _GrainOverlayState extends State<GrainOverlay> {
  ui.Image? _image = GrainTexture.image;

  @override
  void initState() {
    super.initState();
    if (_image == null) {
      GrainTexture.load().then((img) {
        if (mounted) setState(() => _image = img);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final img = _image;
    if (img == null) return const SizedBox.expand();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _GrainPainter(img, widget.opacity, widget.blendMode),
        ),
      ),
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.image, this.opacity, this.blendMode);

  final ui.Image image;
  final double opacity;
  final BlendMode blendMode;

  @override
  void paint(Canvas canvas, Size size) {
    final m = Float64List(16)
      ..[0] = 0.5
      ..[5] = 0.5
      ..[10] = 1
      ..[15] = 1;
    final paint = Paint()
      ..shader = ImageShader(image, TileMode.repeated, TileMode.repeated, m)
      ..blendMode = blendMode
      ..color = Color.fromRGBO(0, 0, 0, opacity);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.image != image || old.opacity != opacity;
}

/// A soft colour spot for [GrainArt].
class Spot {
  const Spot(this.color, this.center, this.radius);
  final Color color;
  final Alignment center;
  final double radius;
}

/// Silky, grainy gradient art: blurred colour spots on a base, plus grain.
class GrainArt extends StatelessWidget {
  const GrainArt({super.key, required this.base, required this.spots, this.grain = 0.5, this.child});

  final Color base;
  final List<Spot> spots;
  final double grain;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: ColoredBox(color: base)),
        for (final s in spots)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: s.center,
                  radius: s.radius,
                  colors: [s.color, s.color.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
        Positioned.fill(child: GrainOverlay(opacity: grain)),
        if (child != null) child!,
      ],
    );
  }
}

/// Named art presets used by folders and hero cards.
class ArtPresets {
  static const all = <String, (Color, List<Spot>)>{
    'ember': (Color(0xFF2A1A16), [
      Spot(Color(0xFFE8452C), Alignment(-0.4, 1.2), 1.0),
      Spot(Color(0xFFF2B66B), Alignment(0.8, -0.8), 0.8),
    ]),
    'tide': (Color(0xFF101827), [
      Spot(Color(0xFF4F7CF0), Alignment(0.4, 1.0), 1.0),
      Spot(Color(0xFFBFE3F2), Alignment(-0.7, -0.7), 0.7),
    ]),
    'moss': (Color(0xFF0F1715), [
      Spot(Color(0xFF5FD3B0), Alignment(0, 1.1), 0.9),
      Spot(Color(0xFFB5A4F0), Alignment(0.7, -0.6), 0.7),
    ]),
    'navy': (Color(0xFF0D1B2A), [
      Spot(Color(0xFF3D5A80), Alignment(-0.6, 1.0), 1.0),
      Spot(Color(0xFFC8D9E6), Alignment(0.8, -0.6), 0.8),
    ]),
    'honey': (Color(0xFFE9E2D6), [
      Spot(Color(0xFFF0A23C), Alignment(0.4, 1.0), 0.9),
      Spot(Color(0xFFF6E3C3), Alignment(-0.6, -0.6), 0.7),
    ]),
    'bloom': (Color(0xFFE6E4EE), [
      Spot(Color(0xFFD88BE0), Alignment(-0.4, 1.0), 0.9),
      Spot(Color(0xFF9CC3F5), Alignment(0.8, -0.7), 0.7),
    ]),
  };

  static List<String> get names => all.keys.toList();

  static bool isLight(String name) => name == 'honey' || name == 'bloom';

  static Widget art(String name, {double grain = 0.55}) {
    final preset = all[name] ?? all['tide']!;
    return GrainArt(base: preset.$1, spots: preset.$2, grain: grain);
  }
}
