import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'models/app_state.dart';
import 'screens/home/home_screen.dart';
import 'screens/analysis/analysis_screen.dart';
import 'screens/results/results_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Heatmap Vision',
        theme: AppTheme.light(),
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (_) => const HomeScreen(),
          '/analysis': (_) => const AnalysisScreen(),
          '/results': (_) => const ResultsScreen(),
        },
      ),
    );
  }
}
