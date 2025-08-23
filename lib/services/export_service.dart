import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/heatmap_metrics.dart';

class ExportService {
  static Future<File> _saveBytes(Uint8List bytes, String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> savePng(Uint8List pngBytes, {String? name}) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return _saveBytes(pngBytes, name ?? 'heatmap_$ts.png');
  }

  static Future<File> saveJson(Map<String, dynamic> data, {String? name}) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));
    return _saveBytes(bytes, name ?? 'heatmap_$ts.json');
  }

  static Future<void> shareFiles(List<File> files, {String? text}) async {
    final xfiles = files.map((f) => XFile(f.path)).toList();
    await Share.shareXFiles(xfiles, text: text);
  }

  /// JSON export'u normalize (0..1) değerlerle üretir.
  static Map<String, dynamic> toJson(HeatmapMetrics m, int w, int h) {
    double nx(double x) => (x / w).clamp(0.0, 1.0);
    double ny(double y) => (y / h).clamp(0.0, 1.0);

    return {
      'image_size': {'width': w, 'height': h},
      'coverage_percent': (m.coverage * 100).toStringAsFixed(1),
      'quadrant_share_percent':
      m.quadrantShare.map((v) => (v * 100).toStringAsFixed(1)).toList(growable: false),
      'thirds_score_percent': (m.thirdsScore * 100).toStringAsFixed(1),
      'centroid_norm': {'x': nx(m.centroid.dx), 'y': ny(m.centroid.dy)},
      'top_hotspots_norm': m.topHotspots
          .map((p) => {'x': nx(p.position.dx), 'y': ny(p.position.dy), 'value': p.value})
          .toList(),
      'low_attention_zones_norm': m.lowAttentionZones
          .map((r) => {
        'left': nx(r.left),
        'top': ny(r.top),
        'width': nx(r.width),
        'height': ny(r.height),
      })
          .toList(),
      'recommended_logo_zone_norm': m.recommendedLogoZone == null
          ? null
          : {
        'left': nx(m.recommendedLogoZone!.left),
        'top': ny(m.recommendedLogoZone!.top),
        'width': nx(m.recommendedLogoZone!.width),
        'height': ny(m.recommendedLogoZone!.height),
      },
      'notes': 'Saliency-based (non-ML) heatmap; not true eye-tracking.',
    };
  }
}
