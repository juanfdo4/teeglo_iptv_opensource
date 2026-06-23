import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'core/theme/app_theme.dart';
import 'presentation/home/pages/main_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  MediaKit.ensureInitialized();
  
  // Open boxes
  await Hive.openBox('playlists');
  await Hive.openBox('favorites');
  await Hive.openBox('history');
  await Hive.openBox('settings');
  await Hive.openBox('playback_progress');

  runApp(
    // Added ProviderScope for Riverpod state management
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teeglo IPTV',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Switch automatically based on OS setting
      home: const MainDashboard(),
    );
  }
}
