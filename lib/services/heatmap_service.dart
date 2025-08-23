import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;

import '../models/heatmap_metrics.dart';

class _IRect {
  final int left, top, right, bottom;
  const _IRect(this.left, this.top, this.right, this.bottom);
  int get width => right - left;
  int get height => bottom - top;
}

class HeatmapService {
  static Future<({Uint8List overlayPng, HeatmapMetrics metrics})> analyze(
      Uint8List bytes,
      ) async {
    final img.Image? src0 = img.decodeImage(bytes);
    if (src0 == null) {
      throw Exception('Failed to decode image.');
    }

    // 1) Resize for speed
    const int maxW = 512;
    final img.Image src = (src0.width > maxW)
        ? img.copyResize(src0, width: maxW)
        : img.copyResize(src0, width: src0.width);
    final int w = src.width, h = src.height;

    // 2) Grayscale -> Sobel -> Gaussian blur (saliency proxy)
    img.Image gray = img.grayscale(src);
    img.Image sob = img.sobel(gray);
    sob = img.gaussianBlur(sob, radius: 3);

    // 3) Normalize 0..1 + center-bias
    final List<double> sal = List<double>.filled(w * h, 0.0);
    double vMin = 1e9, vMax = -1e9;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final p = sob.getPixel(x, y);
        final d = img.getLuminance(p).toDouble(); // 0..255
        sal[y * w + x] = d;
        if (d < vMin) vMin = d;
        if (d > vMax) vMax = d;
      }
    }
    double range = (vMax - vMin).abs();
    if (range < 1e-6) range = 1.0;

    final cx = (w - 1) / 2.0, cy = (h - 1) / 2.0;
    final double sigma = 0.35 * math.min(w, h);

    double sumWeights = 0.0, sumX = 0.0, sumY = 0.0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        double v = (sal[y * w + x] - vMin) / range; // 0..1
        final dx = x - cx, dy = y - cy;
        final centerBias = math.exp(-(dx * dx + dy * dy) / (2 * sigma * sigma));
        v = (0.85 * v + 0.15 * centerBias);
        sal[y * w + x] = v;
        sumWeights += v;
        sumX += x * v;
        sumY += y * v;
      }
    }

    // 4) Coverage & quadrant share
    double maxSal = 1e-9;
    for (final v in sal) {
      if (v > maxSal) maxSal = v;
    }
    final double thr = 0.60 * maxSal;
    int highCnt = 0;
    double tl = 0, tr = 0, bl = 0, br = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final v = sal[y * w + x];
        if (v >= thr) highCnt++;
        final bool top = y < h / 2.0, left = x < w / 2.0;
        if (top && left) tl += v;
        else if (top && !left) tr += v;
        else if (!top && left) bl += v;
        else br += v;
      }
    }
    final coverage = highCnt / (w * h);
    final totalQuad = tl + tr + bl + br + 1e-9;
    final quadrantShare = <double>[tl, tr, bl, br].map((v) => v / totalQuad).toList();

    // 5) Top hotspots (non-max suppression)
    List<PointHotspot> top = [];
    final List<double> mapCopy = List<double>.from(sal);
    for (int k = 0; k < 3; k++) {
      double best = -1.0; int bx = 0, by = 0;
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final v = mapCopy[y * w + x];
          if (v > best) { best = v; bx = x; by = y; }
        }
      }
      if (best <= 0) break;
      top.add(PointHotspot(position: ui.Offset(bx.toDouble(), by.toDouble()), value: best));

      const int rad = 18;
      for (int yy = math.max(0, by - rad); yy < math.min(h, by + rad + 1); yy++) {
        for (int xx = math.max(0, bx - rad); xx < math.min(w, bx + rad + 1); xx++) {
          final dx = xx - bx, dy = yy - by;
          if (dx * dx + dy * dy <= rad * rad) mapCopy[yy * w + xx] = 0.0;
        }
      }
    }

    // 6) Centroid & thirds score
    final ui.Offset centroid = (sumWeights > 0)
        ? ui.Offset(sumX / sumWeights, sumY / sumWeights)
        : const ui.Offset(0, 0);

    final thirds = <ui.Offset>[
      ui.Offset(w / 3.0, h / 3.0),
      ui.Offset(2 * w / 3.0, h / 3.0),
      ui.Offset(w / 3.0, 2 * h / 3.0),
      ui.Offset(2 * w / 3.0, 2 * h / 3.0),
    ];
    double minDist = 1e9;
    for (final p in thirds) {
      final d = (p - centroid).distance;
      if (d < minDist) minDist = d;
    }
    final double maxRef =
    math.sqrt(math.pow(w / 3.0, 2) + math.pow(h / 3.0, 2).toDouble());
    final double thirdsScore = (1.0 - (minDist / maxRef)).clamp(0.0, 1.0);

    // 7) Low-attention corners + recommended
    final rw = (w * 0.28).round();
    final rh = (h * 0.22).round();
    final List<_IRect> candidateRects = <_IRect>[
      _IRect(0, h - rh, rw, h),            // BL
      _IRect(w - rw, h - rh, w, h),        // BR
      _IRect(0, 0, rw, rh),                // TL
      _IRect(w - rw, 0, w, rh),            // TR
    ];

    List<ui.Rect> lowZones = <ui.Rect>[];
    double bestMean = 1e9;
    ui.Rect? recommended;
    for (final r in candidateRects) {
      double sum = 0;
      for (int yy = r.top; yy < r.bottom; yy++) {
        for (int xx = r.left; xx < r.right; xx++) {
          sum += sal[yy * w + xx];
        }
      }
      final mean = sum / (r.width * r.height);
      if (mean < 0.22) {
        lowZones.add(ui.Rect.fromLTWH(
          r.left.toDouble(), r.top.toDouble(),
          r.width.toDouble(), r.height.toDouble(),
        ));
      }
      if (mean < bestMean) {
        bestMean = mean;
        recommended = ui.Rect.fromLTWH(
          r.left.toDouble(), r.top.toDouble(),
          r.width.toDouble(), r.height.toDouble(),
        );
      }
    }

    // 8) Build heatmap overlay at original size
    final img.Image salImg = img.Image(width: w, height: h);
    double maxSal2 = 1e-9;
    for (final v in sal) { if (v > maxSal2) maxSal2 = v; }
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final v = (sal[y * w + x] / maxSal2).clamp(0.0, 1.0);
        final c = _colormap(v);
        salImg.setPixelRgba(x, y, c.$1, c.$2, c.$3, c.$4);
      }
    }
    final img.Image overlay = img.copyResize(
      salImg,
      width: src0.width,
      height: src0.height,
      interpolation: img.Interpolation.average,
    );

    final metrics = HeatmapMetrics(
      topHotspots: top,
      centroid: centroid,
      thirdsScore: thirdsScore,
      lowAttentionZones: lowZones,
      coverage: coverage,
      quadrantShare: quadrantShare,
      recommendedLogoZone: recommended,
      mapWidth: w,
      mapHeight: h,
      originalWidth: src0.width,
      originalHeight: src0.height,
    );

    return (overlayPng: Uint8List.fromList(img.encodePng(overlay)), metrics: metrics);
  }

  static (int, int, int, int) _colormap(double v) {
    v = v.clamp(0.0, 1.0);
    double r = 0, g = 0, b = 0;
    if (v < 0.25) { r = 0; g = v / 0.25; b = 1.0; }
    else if (v < 0.5) { r = 0; g = 1.0; b = 1.0 - (v - 0.25) / 0.25; }
    else if (v < 0.75) { r = (v - 0.5) / 0.25; g = 1.0; b = 0.0; }
    else { r = 1.0; g = 1.0 - (v - 0.75) / 0.25; b = 0.0; }
    final gamma = 0.65;
    final a = (220.0 * math.pow(v, gamma)).clamp(0, 220).round();
    return ((r * 255).round(), (g * 255).round(), (b * 255).round(), a);
  }
}
