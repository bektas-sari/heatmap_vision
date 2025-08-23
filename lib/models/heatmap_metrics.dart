import 'dart:ui';

class PointHotspot {
  final Offset position; // px (working map space)
  final double value;    // 0..1
  const PointHotspot({required this.position, required this.value});
}

class HeatmapMetrics {
  // Existing
  final List<PointHotspot> topHotspots; // strongest first
  final Offset centroid;                // weighted center (working map space)
  final double thirdsScore;             // 0..1, centroid to thirds points
  final List<Rect> lowAttentionZones;   // Rects in working map space
  final double coverage;                // 0..1, high-attention pixel ratio
  final List<double> quadrantShare;     // [TL, TR, BL, BR] sums to 1
  final Rect? recommendedLogoZone;      // working map space

  // NEW: to map working-map -> original image
  final int mapWidth;
  final int mapHeight;
  final int originalWidth;
  final int originalHeight;

  const HeatmapMetrics({
    required this.topHotspots,
    required this.centroid,
    required this.thirdsScore,
    required this.lowAttentionZones,
    required this.coverage,
    required this.quadrantShare,
    required this.recommendedLogoZone,
    required this.mapWidth,
    required this.mapHeight,
    required this.originalWidth,
    required this.originalHeight,
  });
}
