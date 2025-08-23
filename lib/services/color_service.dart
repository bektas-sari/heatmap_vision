import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

class PaletteResult {
  final List<String> dominantHex; // ana renk önerileri (#RRGGBB)
  final List<String> accentHex;   // vurgu renkleri (#RRGGBB)
  const PaletteResult({required this.dominantHex, required this.accentHex});
}

class _Bin {
  double r = 0, g = 0, b = 0, w = 0;
  void add(int rr, int gg, int bb, double weight) {
    r += rr; g += gg; b += bb; w += weight;
  }
}

class ColorService {
  /// Görseli decode ederken küçülterek (≤128px genişlik) RGBA ham baytlarını alır,
  /// basit 12-bit renk ızgarasında (4-4-4) oylama yaparak palet çıkarır.
  static Future<PaletteResult> extractPalette(Uint8List bytes) async {
    // Önce boyutları öğren
    final codec0 = await ui.instantiateImageCodec(bytes);
    final frame0 = await codec0.getNextFrame();
    final src = frame0.image;
    final maxW = 128;
    final scale = src.width > maxW ? maxW / src.width : 1.0;
    final tw = (src.width * scale).round().clamp(1, src.width);
    final th = (src.height * scale).round().clamp(1, src.height);

    // Küçültülmüş decode
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: tw, targetHeight: th);
    final frame = await codec.getNextFrame();
    final ui.Image small = frame.image;

    final byteData = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      return const PaletteResult(dominantHex: ['#CCCCCC'], accentHex: ['#FF3B30']);
    }
    final data = byteData.buffer.asUint8List();

    final Map<int, _Bin> binsAll = {};
    final Map<int, _Bin> binsAccent = {};

    // RGBA dizisi: [r,g,b,a, r,g,b,a, ...]
    for (int i = 0; i < data.length; i += 4) {
      final r = data[i];
      final g = data[i + 1];
      final b = data[i + 2];
      // a = data[i + 3]; // alfa gerekmiyor

      final hsv = _rgbToHsv(r.toDouble(), g.toDouble(), b.toDouble());

      // 12-bit grid anahtarı (4-4-4)
      final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      (binsAll[key] ??= _Bin()).add(r, g, b, 1.0);

      // Accent: daha doygun & parlak pikseller
      if (hsv.$2 >= 0.35 && hsv.$3 >= 0.55) {
        (binsAccent[key] ??= _Bin()).add(r, g, b, hsv.$2 + hsv.$3);
      }
    }

    String toHex(int r, int g, int b) =>
        '#${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
            '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
            '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';

    List<String> pickTop(Map<int, _Bin> map, int k) {
      final arr = map.values.toList()
        ..sort((a, b) => b.w.compareTo(a.w));
      final out = <String>[];
      for (final bin in arr.take(k)) {
        final rc = (bin.r / bin.w).round().clamp(0, 255);
        final gc = (bin.g / bin.w).round().clamp(0, 255);
        final bc = (bin.b / bin.w).round().clamp(0, 255);
        out.add(toHex(rc, gc, bc));
      }
      return out;
    }

    final dominants = pickTop(binsAll, 3);
    var accents = pickTop(binsAccent, 2);
    if (accents.isEmpty) accents = ['#FF3B30']; // güvenli varsayılan vurgu

    return PaletteResult(dominantHex: dominants, accentHex: accents);
  }
}

/// r,g,b ∈ [0..255]  →  (h ∈ [0,360), s ∈ [0..1], v ∈ [0..1])
(double, double, double) _rgbToHsv(double r, double g, double b) {
  final rf = r / 255.0, gf = g / 255.0, bf = b / 255.0;
  final maxv = math.max(rf, math.max(gf, bf));
  final minv = math.min(rf, math.min(gf, bf));
  final d = maxv - minv;

  double h;
  if (d == 0) {
    h = 0.0;
  } else if (maxv == rf) {
    h = 60.0 * (((gf - bf) / (d == 0 ? 1.0 : d)) % 6.0);
  } else if (maxv == gf) {
    h = 60.0 * (((bf - rf) / (d == 0 ? 1.0 : d)) + 2.0);
  } else {
    h = 60.0 * (((rf - gf) / (d == 0 ? 1.0 : d)) + 4.0);
  }
  if (h < 0) h += 360.0;

  final s = maxv == 0.0 ? 0.0 : d / maxv;
  final v = maxv;
  return (h, s, v);
}
