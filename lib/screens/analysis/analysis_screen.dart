import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_state.dart';
import '../../services/heatmap_service.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _running = false;
  String? _error;

  Future<void> _run() async {
    final app = context.read<AppState>();
    final file = app.selectedImage;
    if (file == null) return;

    setState(() {
      _running = true;
      _error = null;
    });

    try {
      final bytes = await file.readAsBytes();
      final result = await HeatmapService.analyze(bytes);
      app.setOverlay(result.overlayPng);
      app.setMetrics(result.metrics);

      if (mounted) Navigator.pushNamed(context, '/results');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Analysis')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('We will generate a heatmap overlay and compute metrics.'),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _running || app.selectedImage == null ? null : _run,
              icon: _running
                  ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(_running ? 'Analyzing...' : 'Run Analysis'),
            ),
          ],
        ),
      ),
    );
  }
}
