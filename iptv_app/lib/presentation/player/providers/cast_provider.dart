import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dart_cast/dart_cast.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/iptv_hls_proxy.dart';
import 'playback_progress_provider.dart';

final _iptvHlsProxy = IptvHlsProxy();

/// MediaTransformer que pasa la URL directamente sin re-procesarla.
///
/// Cuando la URL ya pasa por nuestro proxy local (IptvHlsProxy), no necesitamos
/// que dart_cast la procese de nuevo. Le decimos al Chromecast que la URL
/// final es directamente nuestra URL local — el Chromecast puede acceder a
/// nuestro servidor HTTP porque está en la misma red WiFi.
class _CustomMediaTransformer implements MediaTransformer {
  const _CustomMediaTransformer();

  @override
  Future<TransformedMedia> transform(CastMedia media, MediaProxy proxy) async {
    // Si la URL es la de nuestro proxy local, la devolvemos directo
    if (media.url.contains('playlist.m3u8')) {
      return TransformedMedia(
        proxyUrl: media.url,
        effectiveType: CastMediaType.hls, // Le decimos al Chromecast que es HLS
      );
    }
    
    // Si es cualquier otro archivo (ej. MP4) y tiene headers, usamos el proxy de dart_cast
    // para que el Chromecast pase por el teléfono y el teléfono envíe los headers (User-Agent)
    final proxyUrl = media.httpHeaders.isNotEmpty
        ? proxy.registerMedia(media.url, headers: media.httpHeaders)
        : media.url;

    return TransformedMedia(
      proxyUrl: proxyUrl,
      effectiveType: media.type,
    );
  }
}

final castServiceProvider = Provider<CastService>((ref) {
  final service = CastService(
    discoveryProviders: [
      ChromecastDiscoveryProvider(),
      AirPlayDiscoveryProvider(),
    ],
    sessionFactory: (device) {
      switch (device.protocol) {
        case CastProtocol.chromecast:
          return ChromecastSession(
            device: device,
            mediaTransformer: const _CustomMediaTransformer(),
          );
        case CastProtocol.airplay:
          return AirPlaySession(device);
        case CastProtocol.dlna:
          throw UnimplementedError('DLNA no soportado aún');
      }
    },
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final castDevicesProvider = StreamProvider<List<CastDevice>>((ref) {
  final service = ref.watch(castServiceProvider);
  return service.startDiscovery();
});

/// Detecta el mejor tipo de media y URL para Chromecast.
/// Devuelve [url, type].
/// 
/// Estrategia:
/// - `.m3u8` → HLS (sin modificar)
/// - `.mp4`  → MP4 (sin modificar) 
/// - `/play/TOKEN` (Xtream token) → URL original como MPEG-TS
///   El proxy de dart_cast inyecta el User-Agent y lo sirve como video/mp2t
/// - todo lo demás → HLS (pass-through por proxy)
({String url, CastMediaType type}) _detectCastMedia(String originalUrl) {
  // Limpiar el fragmento de la URL (#.mkv, #.mp4, etc.)
  // Xtream Codes usa estos fragmentos como pistas (hints) del formato real del VOD.
  final cleanUrl = originalUrl.contains('#')
      ? originalUrl.substring(0, originalUrl.indexOf('#'))
      : originalUrl;

  // Extraer la extensión (ya sea la real al final, o la falsa en el fragmento)
  final lowerOriginal = originalUrl.toLowerCase();

  // PRIMERO: Respetar las pistas de formato. 
  // Si la app sabe que es MP4/MKV/M3U8 (por el fragmento o extensión), debemos enviar ese tipo
  // directamente al Chromecast SIN pasarlo por el proxy de MPEG-TS.
  // Los VODs (películas/series) usan URLs de token pero NO son MPEG-TS, son MP4/MKV.
  if (lowerOriginal.endsWith('.m3u8')) {
    return (url: cleanUrl, type: CastMediaType.hls);
  }
  if (lowerOriginal.endsWith('.mp4')) {
    return (url: cleanUrl, type: CastMediaType.mp4);
  }
  if (lowerOriginal.endsWith('.mkv')) {
    return (url: cleanUrl, type: CastMediaType.mkv);
  }

  // LUEGO: Detectar URLs de token Xtream Codes (/play/TOKEN o /stream/TOKEN)
  // Si llegamos aquí, es un token sin pista de formato. Asumimos que es un CANAL EN VIVO (MPEG-TS)
  final isTokenUrl = RegExp(r'/(?:play|stream)/[A-Za-z0-9_\-]{20,}$').hasMatch(cleanUrl);
  if (isTokenUrl) {
    debugPrint('CAST_LOG: URL tipo token sin formato explícito — asumiendo Live Stream (MPEG-TS)');
    return (url: cleanUrl, type: CastMediaType.mpegTs);
  }

  // Si termina en .ts
  if (lowerOriginal.endsWith('.ts')) {
    return (url: cleanUrl, type: CastMediaType.mpegTs);
  }

  // Fallback
  return (url: cleanUrl, type: CastMediaType.hls);
}

class CastState {
  final CastSession? session;
  final SessionState? mediaStatus;
  final String? errorMessage;
  final String? playingTitle;
  final String? playingUrl;

  const CastState({
    this.session, 
    this.mediaStatus, 
    this.errorMessage,
    this.playingTitle,
    this.playingUrl,
  });

  CastState copyWith({
    CastSession? session,
    SessionState? mediaStatus,
    String? errorMessage,
    String? playingTitle,
    String? playingUrl,
  }) {
    return CastState(
      session: session ?? this.session,
      mediaStatus: mediaStatus ?? this.mediaStatus,
      errorMessage: errorMessage, // errorMessage null overrides unless specified? No, usually copyWith sets null if explicitly passed, but let's keep it simple.
      playingTitle: playingTitle ?? this.playingTitle,
      playingUrl: playingUrl ?? this.playingUrl,
    );
  }
}

class CastNotifier extends Notifier<CastState> {
  StreamSubscription? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;

  @override
  CastState build() {
    // Intentar restaurar dispositivo previo
    _restoreLastDevice();
    return CastState();
  }

  void _restoreLastDevice() {
    try {
      final box = Hive.box('settings');
      final lastDeviceJson = box.get('last_cast_device');
      if (lastDeviceJson != null) {
        // Safe conversion from Hive Map<dynamic, dynamic> to Map<String, dynamic>
        final map = (lastDeviceJson as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        );
        if (map['metadata'] != null) {
          map['metadata'] = (map['metadata'] as Map).map(
            (key, value) => MapEntry(key.toString(), value),
          );
        }
        final device = CastDevice.fromJson(map);
        
        final title = box.get('last_cast_title');
        final url = box.get('last_cast_url');
        
        state = state.copyWith(
          playingTitle: title,
          playingUrl: url,
        );
        
        _reconnect(device);
      }
    } catch (e) {
      debugPrint('Error restoring cast device: $e');
    }
  }

  Future<void> _reconnect(CastDevice device) async {
    try {
      final service = ref.read(castServiceProvider);
      final session = await service.connect(device);
      state = state.copyWith(session: session);
      _listenToSession(session);
      
      // Si tenemos un canal en progreso, intentamos relanzarlo si el Chromecast está inactivo
      // Esto pasa cuando la app se cierra y el proxy local muere, desconectando el TV.
      if (state.playingUrl != null && state.playingTitle != null) {
        await Future.delayed(const Duration(seconds: 2));
        final sState = session.stateMachine.state;
        if (sState == SessionState.idle || sState == SessionState.connected || sState == SessionState.disconnected) {
          debugPrint('CAST_LOG: Auto-reanudando última transmisión al reconectar...');
          castUrl(state.playingUrl!, state.playingTitle!);
        }
      }
    } catch (e) {
      debugPrint('Error reconnecting to cast: $e');
      Hive.box('settings').delete('last_cast_device');
    }
  }

  void _listenToSession(CastSession session) {
    _stateSubscription?.cancel();
    _stateSubscription = session.stateMachine.stateStream.listen((sessionState) {
      if (sessionState == SessionState.disconnected) {
        state = state.copyWith(session: null);
      }
    });
  }

  Future<void> connectToDevice(CastDevice device) async {
    try {
      final service = ref.read(castServiceProvider);
      final session = await service.connect(device);
      state = state.copyWith(session: session, errorMessage: null);

      // Guardar para futura reconexión
      try {
        Hive.box('settings').put('last_cast_device', device.toJson());
      } catch (e) {
        debugPrint('Error saving cast device: $e');
      }

      _listenToSession(session);
    } catch (e) {
      state = state.copyWith(errorMessage: 'No se pudo conectar al dispositivo');
      debugPrint('CAST_LOG: Error al conectar - $e');
    }
  }

  Future<void> castUrl(String url, String title) async {
    final session = state.session;
    if (session == null) return;

    try {
      state = state.copyWith(errorMessage: null);
      debugPrint('CAST_LOG: =========================================');
      debugPrint('CAST_LOG: Solicitud de transmisión original: $url');
      debugPrint('CAST_LOG: =========================================');

      final media = _detectCastMedia(url);
      String finalUrl = media.url;
      CastMediaType finalType = media.type;

      // Para streams TS / tokens de IPTV: usar proxy HLS local en el teléfono.
      // Esto garantiza que la petición al servidor IPTV sale del teléfono
      // (con el User-Agent correcto y la IP correcta), no del Chromecast.
      if (media.type == CastMediaType.mpegTs) {
        debugPrint('CAST_LOG: Iniciando proxy HLS local para stream TS...');
        await _iptvHlsProxy.start(url, {
          'User-Agent': 'VLC/3.0.9 LibVLC/3.0.9',
          'Connection': 'keep-alive',
        });

        final proxyStream = _iptvHlsProxy.streamUrl;
        if (proxyStream != null) {
          finalUrl = proxyStream;
          // El Chromecast se conectará directamente a nuestro proxy local al archivo .ts
          // Le pasamos mpegTs para que dart_cast sepa que es TS y aplique su TsDvbStripper
          finalType = CastMediaType.mpegTs; 
          debugPrint('CAST_LOG: Usando proxy local → $finalUrl');
        } else {
          throw Exception('No se pudo obtener la URL del proxy local');
        }
      }

      debugPrint('CAST_LOG: Enviando al Chromecast: $finalUrl (tipo: $finalType)');

      state = state.copyWith(
        playingTitle: title,
        playingUrl: url,
      );

      try {
        Hive.box('settings').put('last_cast_title', title);
        Hive.box('settings').put('last_cast_url', url);
      } catch (e) {
        debugPrint('Error saving cast title: $e');
      }

      await session.loadMedia(CastMedia(
        url: finalUrl,
        type: finalType,
        title: title,
        httpHeaders: const {
          'User-Agent': 'VLC/3.0.9 LibVLC/3.0.9',
          'Connection': 'keep-alive',
        },
      ));

      final progressService = ref.read(playbackProgressProvider);
      
      // Auto-seek si había progreso guardado
      final lastPos = progressService.getProgress(url);
      if (lastPos != null && lastPos.inSeconds > 0) {
        try {
          debugPrint('CAST_LOG: Restaurando posición a ${lastPos.inSeconds}s');
          await session.seek(lastPos);
        } catch (e) {
          debugPrint('CAST_LOG: Error buscando posición: $e');
        }
      }

      // Guardar el progreso de reproducción en Chromecast
      _positionSubscription?.cancel();
      _positionSubscription = session.positionStream.listen((position) {
        final duration = session.duration;
        if (duration.inSeconds > 0) {
          // El finalUrl podría ser el proxy. Guardamos con la url original del canal (url)
          progressService.saveProgress(url, position, duration);
        }
      });
    } catch (e) {
      debugPrint('CAST_LOG: Error al cargar media - $e');
      await _iptvHlsProxy.stop();
      state = state.copyWith(
        errorMessage: 'Este canal no pudo cargarse en el Chromecast.\nIntenta con otro canal.',
      );
    }
  }

  Future<void> disconnect() async {
    await _iptvHlsProxy.stop();
    if (state.session != null) {
      await state.session!.disconnect();
      _stateSubscription?.cancel();
    }
    state = CastState();
  }
}

final castNotifierProvider = NotifierProvider<CastNotifier, CastState>(() {
  return CastNotifier();
});
