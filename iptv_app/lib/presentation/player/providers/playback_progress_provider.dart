import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final playbackProgressProvider = Provider<PlaybackProgressService>((ref) {
  return PlaybackProgressService();
});

class PlaybackProgressService {
  final Box _box = Hive.box('playback_progress');

  /// Guarda el progreso de reproducción. 
  /// Solo guardamos si el video dura más de 0 segundos (no es en vivo) y el progreso es > 5%.
  void saveProgress(String url, Duration position, Duration duration) {
    if (duration.inSeconds == 0) return;
    
    // Si ya vio más del 95%, lo marcamos como completado (borramos el progreso)
    if (position.inSeconds > duration.inSeconds * 0.95) {
      _box.delete(url);
    } 
    // Si vio más del 5%, guardamos el progreso
    else if (position.inSeconds > duration.inSeconds * 0.05) {
      _box.put(url, position.inSeconds);
    }
  }

  /// Retorna el progreso guardado en segundos, o nulo si no hay progreso
  Duration? getProgress(String url) {
    final seconds = _box.get(url) as int?;
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds);
    }
    return null;
  }

  /// Elimina el progreso guardado
  void clearProgress(String url) {
    _box.delete(url);
  }
}
