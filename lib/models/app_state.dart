import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'heatmap_metrics.dart';

class AppState extends ChangeNotifier {
  XFile? _selectedImage;
  Uint8List? _overlayPng;
  HeatmapMetrics? _metrics;
  double _overlayOpacity = 0.6;

  XFile? get selectedImage => _selectedImage;
  Uint8List? get overlayPng => _overlayPng;
  HeatmapMetrics? get metrics => _metrics;
  double get overlayOpacity => _overlayOpacity;

  void setSelectedImage(XFile? file) {
    _selectedImage = file;
    notifyListeners();
  }

  void setOverlay(Uint8List? pngBytes) {
    _overlayPng = pngBytes;
    notifyListeners();
  }

  void setMetrics(HeatmapMetrics? m) {
    _metrics = m;
    notifyListeners();
  }

  void setOpacity(double v) {
    _overlayOpacity = v.clamp(0.0, 1.0);
    notifyListeners();
  }

  void reset() {
    _selectedImage = null;
    _overlayPng = null;
    _metrics = null;
    _overlayOpacity = 0.6;
    notifyListeners();
  }
}
