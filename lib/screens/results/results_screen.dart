import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../models/app_state.dart';
import '../../models/heatmap_metrics.dart';
import '../../services/export_service.dart';
import '../../services/color_service.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final GlobalKey _captureKey = GlobalKey();

  Future<Uint8List> _capturePng() async {
    final boundary =
    _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
    final byteData =
    await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final imgFile = app.selectedImage;

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: (imgFile == null || app.overlayPng == null || app.metrics == null)
            ? const Center(child: Text('No results. Go back and analyze an image.'))
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Image + Heatmap + Logo guide (capturable)
            Expanded(
              flex: 6,
              child: RepaintBoundary(
                key: _captureKey,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          FutureBuilder<Uint8List>(
                            future: imgFile.readAsBytes(),
                            builder: (context, snap) {
                              if (!snap.hasData) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              return Image.memory(snap.data!, fit: BoxFit.contain);
                            },
                          ),
                          Opacity(
                            opacity: app.overlayOpacity,
                            child: Image.memory(app.overlayPng!, fit: BoxFit.contain),
                          ),
                          // Logo suggestion rectangle + X
                          Positioned.fill(
                            child: _GuideOverlay(metrics: app.metrics!),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Bottom: scrollable details (no overflow)
            Expanded(
              flex: 7,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // Opacity slider
                  Row(
                    children: [
                      const Text('Overlay Opacity'),
                      Expanded(
                        child: Slider(
                          value: app.overlayOpacity,
                          onChanged: (v) => app.setOpacity(v),
                          min: 0.0,
                          max: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Key Insights (English, human-friendly)
                  const _KeyInsightsCard(),
                  const SizedBox(height: 8),

                  // Analyst Notes (English, action-oriented)
                  const _AnalystNotesCard(),
                  const SizedBox(height: 8),

                  // Design Hints (palette + fonts)
                  const _DesignHintsCard(),
                  const SizedBox(height: 10),

                  // Export / Share buttons
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            final pngBytes = await _capturePng();
                            final f = await ExportService.savePng(pngBytes);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('PNG exported: ${f.path}')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Export PNG failed: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Export PNG'),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            final original = await imgFile.readAsBytes();
                            // Use original image size
                            final m = app.metrics!;
                            final jsonFile = await ExportService.saveJson(
                              ExportService.toJson(m, m.originalWidth, m.originalHeight),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('JSON exported: ${jsonFile.path}')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Export JSON failed: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.data_object_outlined),
                        label: const Text('Export JSON'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            final pngBytes = await _capturePng();
                            final png = await ExportService.savePng(pngBytes);
                            final m = app.metrics!;
                            final json = await ExportService.saveJson(
                              ExportService.toJson(m, m.originalWidth, m.originalHeight),
                            );
                            await ExportService.shareFiles(
                              [png, json],
                              text: 'Heatmap Vision export',
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Share failed: $e')),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.share_outlined),
                        label: const Text('Share'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =========================== OVERLAY (Logo guide) ============================

class _GuideOverlay extends StatelessWidget {
  final HeatmapMetrics metrics;
  const _GuideOverlay({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GuidePainter(
        metrics: metrics,
        originalW: metrics.originalWidth.toDouble(),
        originalH: metrics.originalHeight.toDouble(),
      ),
    );
  }
}

class _GuidePainter extends CustomPainter {
  final HeatmapMetrics metrics;
  final double originalW, originalH;
  _GuidePainter({required this.metrics, required this.originalW, required this.originalH});

  @override
  void paint(Canvas canvas, Size size) {
    // BoxFit.contain mapping
    final input = Size(originalW, originalH);
    final output = size;
    final fitted = applyBoxFit(BoxFit.contain, input, output);
    final drawSize = Size(fitted.destination.width, fitted.destination.height);
    final dx = (output.width - drawSize.width) / 2;
    final dy = (output.height - drawSize.height) / 2;
    final offset = Offset(dx, dy);

    // working-map -> original -> screen
    final sx = (metrics.originalWidth / metrics.mapWidth);
    final sy = (metrics.originalHeight / metrics.mapHeight);

    final rectPaint = Paint()
      ..color = const Color(0xFF1E88E5).withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final xPaint = Paint()
      ..color = const Color(0xFF1E88E5).withOpacity(0.9)
      ..strokeWidth = 2;

    if (metrics.recommendedLogoZone != null) {
      final r = metrics.recommendedLogoZone!;
      final rOrig = Rect.fromLTWH(r.left * sx, r.top * sy, r.width * sx, r.height * sy);
      final scaleX = drawSize.width / originalW;
      final scaleY = drawSize.height / originalH;
      final rScreen = Rect.fromLTWH(
        offset.dx + rOrig.left * scaleX,
        offset.dy + rOrig.top * scaleY,
        rOrig.width * scaleX,
        rOrig.height * scaleY,
      );
      canvas.drawRect(rScreen, rectPaint);
      canvas.drawLine(rScreen.topLeft, rScreen.bottomRight, xPaint);
      canvas.drawLine(rScreen.topRight, rScreen.bottomLeft, xPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GuidePainter oldDelegate) {
    return oldDelegate.metrics != metrics ||
        oldDelegate.originalW != originalW ||
        oldDelegate.originalH != originalH;
  }
}

/// ===================== HUMAN-FRIENDLY DESCRIPTORS (EN) =======================

String _quadrantEN(ui.Offset p, double w, double h) {
  final left = p.dx < w / 2, top = p.dy < h / 2;
  if (top && left) return 'Top-Left';
  if (top && !left) return 'Top-Right';
  if (!top && left) return 'Bottom-Left';
  return 'Bottom-Right';
}

String _positionDescriptorEN(ui.Offset p, double w, double h) {
  final cx = w / 2, cy = h / 2;
  final minSide = math.min(w, h).toDouble();

  final dCenter = (p - ui.Offset(cx, cy)).distance;
  final nearCenter = dCenter < 0.18 * minSide;

  final dLeft = p.dx, dRight = (w - p.dx), dTop = p.dy, dBottom = (h - p.dy);
  final minEdge = [dLeft, dRight, dTop, dBottom].reduce(math.min);
  final nearEdge = minEdge < 0.08 * minSide;

  final corners = [
    const ui.Offset(0, 0),
    ui.Offset(w, 0),
    ui.Offset(0, h),
    ui.Offset(w, h),
  ];
  double minCorner = 1e9;
  for (final c in corners) {
    final d = (p - c).distance;
    if (d < minCorner) minCorner = d;
  }
  final nearCorner = minCorner < 0.18 * minSide;

  if (nearCorner) return 'near a corner';
  if (nearCenter) return 'near the center';
  if (nearEdge) return 'close to an edge';
  return 'around the mid area';
}

bool _nearThirdsPoint(ui.Offset p, double w, double h) {
  final pts = <ui.Offset>[
    ui.Offset(w / 3, h / 3),
    ui.Offset(2 * w / 3, h / 3),
    ui.Offset(w / 3, 2 * h / 3),
    ui.Offset(2 * w / 3, 2 * h / 3),
  ];
  final tol = 0.08 * math.min(w, h);
  for (final t in pts) {
    if ((p - t).distance <= tol) return true;
  }
  return false;
}

String _rectLabelEN(ui.Rect r, double w, double h) {
  final c = r.center;
  final q = _quadrantEN(c, w, h);
  final isTop = r.top <= h * 0.05;
  final isLeft = r.left <= w * 0.05;
  final isRight = r.right >= w * 0.95; // fixed: use w (not h)
  final isBottom = r.bottom >= h * 0.95;
  if (isTop && isLeft) return 'Top-Left corner';
  if (isTop && isRight) return 'Top-Right corner';
  if (isBottom && isLeft) return 'Bottom-Left corner';
  if (isBottom && isRight) return 'Bottom-Right corner';
  return '$q area';
}

/// ============================== KEY INSIGHTS ================================

class _KeyInsightsCard extends StatelessWidget {
  const _KeyInsightsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = context.watch<AppState>().metrics!;
    final w = m.originalWidth.toDouble();
    final h = m.originalHeight.toDouble();

    String hotspotsHuman(List<ui.Offset> pts) {
      if (pts.isEmpty) return 'No strong hotspots detected.';
      final parts = <String>[];
      for (final p in pts) {
        final pOrig = ui.Offset(
          p.dx * (m.originalWidth / m.mapWidth),
          p.dy * (m.originalHeight / m.mapHeight),
        );
        final where = _positionDescriptorEN(pOrig, w, h);
        final q = _quadrantEN(pOrig, w, h);
        final thirds = _nearThirdsPoint(pOrig, w, h) ? ', near rule-of-thirds point' : '';
        parts.add('$q, $where$thirds');
      }
      return parts.join(' • ');
    }

    String logoText() {
      if (m.recommendedLogoZone == null) {
        return 'No clearly low-attention corner. Keep the logo small and leave ≥6% safe margin from edges.';
      }
      final label = _rectLabelEN(
          ui.Rect.fromLTWH(
            m.recommendedLogoZone!.left * (m.originalWidth / m.mapWidth),
            m.recommendedLogoZone!.top * (m.originalHeight / m.mapHeight),
            m.recommendedLogoZone!.width * (m.originalWidth / m.mapWidth),
            m.recommendedLogoZone!.height * (m.originalHeight / m.mapHeight),
          ),
          w, h);
      return 'Recommended logo area: $label. Leave ≥6% safe margin; avoid hotspots.';
    }

    String lowZonesText() {
      if (m.lowAttentionZones.isEmpty) return 'No clear low-attention zones.';
      final names = m.lowAttentionZones.map((r) => _rectLabelEN(
          ui.Rect.fromLTWH(
            r.left * (m.originalWidth / m.mapWidth),
            r.top * (m.originalHeight / m.mapHeight),
            r.width * (m.originalWidth / m.mapWidth),
            r.height * (m.originalHeight / m.mapHeight),
          ),
          w, h)).toList();
      final uniq = <String>{}..addAll(names);
      return 'Low-attention zones: ${uniq.join(', ')}.';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Key Insights', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Coverage (high-attention area): ${(m.coverage * 100).toStringAsFixed(0)}%'),
            Text('Rule of Thirds alignment: ${(m.thirdsScore * 100).toStringAsFixed(0)}%'),
            Text('Top attention hotspots: ${hotspotsHuman(m.topHotspots.map((e) => e.position).toList())}'),
            Text(logoText()),
            Text(lowZonesText()),
          ],
        ),
      ),
    );
  }
}

/// ============================== ANALYST NOTES ===============================

class _AnalystNotesCard extends StatelessWidget {
  const _AnalystNotesCard();

  String _thirdsLabel(double s) {
    if (s >= 0.75) return 'Strong alignment';
    if (s >= 0.50) return 'Moderate alignment';
    return 'Weak alignment';
  }

  String _coverageLabel(double c) {
    final p = (c * 100);
    if (p >= 55) return 'High spread (crowded background risk)';
    if (p >= 30) return 'Moderate spread (balanced)';
    return 'Low spread (strong focal isolation)';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = context.watch<AppState>().metrics!;

    final thirdsTxt = _thirdsLabel(m.thirdsScore);
    final covTxt = _coverageLabel(m.coverage);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Analyst Notes', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// ============================= DESIGN HINTS =================================

class _DesignHintsCard extends StatelessWidget {
  const _DesignHintsCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.watch<AppState>();
    final imgFile = app.selectedImage!;
    return FutureBuilder<PaletteResult>(
      future: imgFile.readAsBytes().then(ColorService.extractPalette),
      builder: (context, snap) {
        final dom = snap.data?.dominantHex ?? const ['#CCCCCC', '#999999', '#666666'];
        final acc = snap.data?.accentHex ?? const ['#FF3B30'];

        Widget chip(String hex) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hexToColor(hex),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: Text(hex, style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: _contrastOn(_hexToColor(hex)),
          )),
        );

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Design Hints', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('• Dominant colors to lean on:'),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 6, children: dom.map(chip).toList()),
                const SizedBox(height: 6),
                const Text('• Accent color(s) for CTA or highlights:'),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 6, children: acc.map(chip).toList()),
                const SizedBox(height: 8),
                const Text('• Typeface suggestions: Headlines → Montserrat / Poppins; Body → Inter; '
                    'CTA/Promo → Roboto Condensed or Oswald. Keep high contrast and ample whitespace.'),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _hexToColor(String hex) {
    final h = hex.replaceAll('#', '');
    final v = int.parse(h, radix: 16);
    return Color(0xFF000000 | v);
  }

  Color _contrastOn(Color c) {
    final luma = 0.2126 * c.red + 0.7152 * c.green + 0.0722 * c.blue;
    return luma > 160 ? Colors.black : Colors.white;
  }
}
