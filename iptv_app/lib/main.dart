import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:audio_service/audio_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/home/pages/main_dashboard.dart';
import 'presentation/splash/splash_screen.dart';
import 'presentation/player/services/cast_audio_handler.dart';

late CastAudioHandler audioHandler;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  MediaKit.ensureInitialized();
  
  // Initialize audio_service for media controls
  audioHandler = await AudioService.init(
    builder: () => CastAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.teeglo.iptv.channel.audio',
      androidNotificationChannelName: 'IPTV Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  
  // Open boxes
  await Hive.openBox('playlists');
  await Hive.openBox('favorites');
  await Hive.openBox('history');
  final settingsBox = await Hive.openBox('settings');
  await Hive.openBox('playback_progress');

  // MIGRATION BLOCK: If the user hasn't run the new version with content types, clear DB
  final isMigrated = settingsBox.get('migrated_ids_v4');
  
  if (isMigrated != 'true') {
    // Clear out old data that might cause collisions or lacks new enum types
    await Hive.deleteBoxFromDisk('playlists');
    await Hive.deleteBoxFromDisk('favorites');
    await Hive.openBox('playlists');
    await Hive.openBox('favorites');
    
    // Mark as migrated
    await settingsBox.put('migrated_ids_v4', 'true');
  }

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
      themeMode: ThemeMode.dark, // Enforce dark theme
      home: const SplashScreen(nextScreen: MainDashboard()),
    );
  }
}
