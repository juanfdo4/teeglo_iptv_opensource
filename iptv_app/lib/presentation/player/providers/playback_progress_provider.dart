import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../domain/entities/channel.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

final playbackProgressProvider = NotifierProvider<PlaybackProgressNotifier, int>(() {
  return PlaybackProgressNotifier();
});

class PlaybackProgressNotifier extends Notifier<int> {
  final Box _box = Hive.box('playback_progress');

  @override
  int build() {
    return 0;
  }

  String _getKey(String url) {
    return md5.convert(utf8.encode(url)).toString();
  }

  void saveProgress(String url, Duration position, Duration duration) {
    if (duration.inSeconds == 0) return;
    
    final key = _getKey(url);
    
    // Si ya vio más del 90%, lo marcamos como completado (watched)
    if (position.inSeconds > duration.inSeconds * 0.90) {
      _box.put('${key}_watched', true);
      _box.delete(key); // Remove partial progress since it's practically finished
      _box.delete('${key}_duration');
      state++;
    } 
    // Si vio más del 5% y no está terminado, guardamos el progreso
    else if (position.inSeconds > duration.inSeconds * 0.05) {
      _box.put(key, position.inSeconds);
      _box.put('${key}_duration', duration.inSeconds);
      state++;
    }
  }

  /// Retorna verdadero si el contenido ya fue visto completamente (>90%)
  bool isWatched(String url) {
    final key = _getKey(url);
    return _box.get('${key}_watched', defaultValue: false) as bool;
  }


  /// Retorna el progreso guardado en segundos, o nulo si no hay progreso
  Duration? getProgress(String url) {
    final key = _getKey(url);
    final seconds = _box.get(key) as int?;
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds);
    }
    return null;
  }

  /// Retorna la duración guardada en segundos, o nulo si no hay
  Duration? getDuration(String url) {
    final key = _getKey(url);
    final seconds = _box.get('${key}_duration') as int?;
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds);
    }
    return null;
  }

  /// Elimina el progreso guardado
  void clearProgress(String url) {
    final key = _getKey(url);
    _box.delete(key);
    _box.delete('${key}_duration');
    _box.delete('${key}_watched');
    state++;
  }

  void markAsWatched(String url) {
    final key = _getKey(url);
    _box.put('${key}_watched', true);
    _box.delete(key);
    _box.delete('${key}_duration');
    state++;
  }

  void markAsUnwatched(String url) {
    final key = _getKey(url);
    _box.delete('${key}_watched');
    _box.delete(key);
    _box.delete('${key}_duration');
    state++;
  }

  void markSeriesAsWatched(List<Channel> episodes) {
    for (var ep in episodes) {
      final key = _getKey(ep.url);
      _box.put('${key}_watched', true);
      _box.delete(key);
      _box.delete('${key}_duration');
    }
    state++;
  }

  void markSeriesAsUnwatched(List<Channel> episodes) {
    for (var ep in episodes) {
      final key = _getKey(ep.url);
      _box.delete('${key}_watched');
      _box.delete(key);
      _box.delete('${key}_duration');
    }
    state++;
  }

  /// Retorna el porcentaje de progreso de una serie (0.0 a 1.0) y si está completada.
  Map<String, dynamic> getSeriesProgress(List<Channel> episodes) {
    if (episodes.isEmpty) return {'progressPercent': 0.0, 'isWatched': false};
    
    int watchedCount = 0;
    double partialSum = 0.0;
    
    for (var ep in episodes) {
      if (isWatched(ep.url)) {
        watchedCount++;
      } else {
        final prog = getProgress(ep.url);
        final dur = getDuration(ep.url);
        if (prog != null && dur != null && dur.inSeconds > 0) {
          partialSum += prog.inSeconds / dur.inSeconds;
        }
      }
    }
    
    if (watchedCount == episodes.length) {
      return {'progressPercent': 1.0, 'isWatched': true};
    }
    
    double totalProgress = (watchedCount + partialSum) / episodes.length;
    return {'progressPercent': totalProgress, 'isWatched': false};
  }
}
