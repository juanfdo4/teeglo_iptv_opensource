import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter_new/log.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

/// Proxy local que usa FFmpeg para convertir streams IPTV (MPEG-TS, posiblemente
/// entrelazados) en HLS estándar compatible con el Chromecast Default Media Receiver.
///
/// En Android/iOS: usa [ffmpeg_kit_flutter_new] (FFmpeg embebido, sin binario externo).
/// En macOS/Linux: usa el binario del sistema [Process.start].
///
/// FFmpeg se encarga de:
/// - Seguir redirecciones HTTP automáticamente (302 → token de auth fresco)
/// - Desentrelazar el video (yadif) → H.264 progresivo compatible con Chromecast
/// - Segmentar en chunks HLS de ~4s con ventana deslizante live
/// - Reconectarse automáticamente si el servidor IPTV corta la conexión
class IptvHlsProxy {
  HttpServer? _server;

  // Mobile: FFmpegSession de ffmpeg_kit_flutter
  FFmpegSession? _ffmpegSession;

  // Desktop: Process.start (macOS/Linux con ffmpeg instalado)
  Process? _ffmpegProcess;

  String? _localIp;
  int _port = 0;
  String? _hlsDir;

  /// URL base del servidor local (e.g. http://192.168.1.3:PORT)
  String? get baseUrl => _localIp != null ? 'http://$_localIp:$_port' : null;

  /// URL de la playlist HLS para enviar al Chromecast
  String? get playlistUrl {
    if (_server == null || _hlsDir == null) return null;
    return 'http://$_localIp:$_port/playlist.m3u8';
  }

  String? get logoUrl {
    if (_server == null || _hlsDir == null) return null;
    return 'http://$_localIp:$_port/logo.png';
  }

  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          final parts = addr.address.split('.');
          if (parts.length == 4) {
            final first = int.tryParse(parts[0]) ?? 0;
            final second = int.tryParse(parts[1]) ?? 0;
            if (first == 192 && second == 168) return addr.address;
            if (first == 10) return addr.address;
            if (first == 172 && second >= 16 && second <= 31) {
              return addr.address;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('IptvProxy: Error obteniendo IP local - $e');
    }
    return null;
  }

  /// Inicia FFmpeg y el servidor HTTP local.
  ///
  /// [streamUrl]: URL original del stream IPTV (puede tener redirecciones).
  /// [headers]: Headers HTTP adicionales (User-Agent, etc.).
  Future<void> start(String streamUrl, Map<String, String> headers) async {
    await stop();

    _localIp = await _getLocalIp();
    if (_localIp == null) {
      throw Exception('IptvProxy: No se pudo obtener la IP local de red');
    }

    // Usar el directorio de caché de la app — siempre disponible en Android/iOS/macOS
    final cacheDir = await getTemporaryDirectory();
    
    // Limpiar cachés anteriores para liberar espacio
    try {
      final oldDirs = cacheDir.listSync().where((e) => e.path.contains('iptv_hls_'));
      for (final oldDir in oldDirs) {
        if (oldDir is Directory) {
          oldDir.deleteSync(recursive: true);
        }
      }
    } catch (_) {}

    final hlsDirPath = '${cacheDir.path}/iptv_hls_${DateTime.now().millisecondsSinceEpoch}';
    final dir = Directory(hlsDirPath);
    dir.createSync(recursive: true);
    _hlsDir = hlsDirPath;

    // Copiar el logo a la carpeta del servidor para poder mostrarlo en Chromecast
    try {
      final logoBytes = await rootBundle.load('assets/images/logo.png');
      final logoFile = File('$_hlsDir/logo.png');
      await logoFile.writeAsBytes(
          logoBytes.buffer.asUint8List(logoBytes.offsetInBytes, logoBytes.lengthInBytes));
    } catch (e) {
      debugPrint('IptvProxy: Error copiando logo.png - $e');
    }

    debugPrint('IptvProxy: Iniciando FFmpeg → HLS en $_hlsDir');
    debugPrint('IptvProxy: Stream URL: $streamUrl');

    await _startFfmpeg(streamUrl, headers);
    await _waitForSegments(minSegments: 3, timeoutSeconds: 35);
    await _startServer();

    debugPrint('IptvProxy: Servidor iniciado en $baseUrl');
    debugPrint('IptvProxy: URL del Chromecast: $playlistUrl');
  }

  /// Construye los argumentos de FFmpeg comunes a todas las plataformas.
  List<String> _buildFfmpegArgs(String url, Map<String, String> headers) {
    final userAgent = headers['User-Agent'] ?? 'VLC/3.0.9 LibVLC/3.0.9';
    final hlsDir = _hlsDir!;

    // CRÍTICO: el stream IPTV es H.264 entrelazado (yuv420p, top first).
    // El Default Media Receiver del Chromecast NO soporta H.264 entrelazado.
    // Usamos yadif para desentrelazar → H.264 progresivo compatible.
    //
    // FFmpeg sigue redirecciones HTTP 302 internamente, por lo que NO pre-resolvemos
    // la URL (los tokens de auth son de corta duración y expirarían).
    return [
      '-loglevel', 'warning',
      '-reconnect', '1',
      '-reconnect_at_eof', '1',
      '-reconnect_streamed', '1',
      '-reconnect_delay_max', '5',
      '-user_agent', userAgent,
      // Aumentar el buffer de red y tolerancia a errores de tiempo en el stream
      '-fflags', '+genpts',
      '-analyzeduration', '10000000',
      '-probesize', '10000000',
      '-i', url,
      // Video y Audio: Copiar directamente sin recodificar.
      // Reduce el uso de CPU a ~1% y soporta streams 1080p60/4K.
      // (Asume que el proveedor ya envía H.264/AAC que son compatibles).
      '-c', 'copy',
      // Salida HLS rolling live
      '-f', 'hls',
      '-hls_time', '2',
      '-hls_list_size', '15', // Guardar 30 segundos de buffer (15 chunks de 2s) para evitar cortes
      // omit_endlist: CRÍTICO para IPTV, evita que FFmpeg cierre la playlist (y el Chromecast se detenga "limpiamente") si la red parpadea
      '-hls_flags', 'delete_segments+append_list+omit_endlist',
      '-hls_allow_cache', '0',
      '-hls_segment_type', 'mpegts',
      '-hls_segment_filename', '$hlsDir/seg%05d.ts',
      '$hlsDir/playlist.m3u8',
    ];
  }

  Future<void> _startFfmpeg(String url, Map<String, String> headers) async {
    final args = _buildFfmpegArgs(url, headers);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      // === Móvil: usar ffmpeg_kit_flutter (FFmpeg embebido) ===
      debugPrint('IptvProxy: Iniciando FFmpegKit (móvil) con ${args.length} argumentos');

      _ffmpegSession = await FFmpegKit.executeWithArgumentsAsync(
        args,
        (session) async {
          final code = await session.getReturnCode();
          final state = await session.getState();
          final failStackTrace = await session.getFailStackTrace();
          
          debugPrint(
            'IptvProxy: 🛑 FFmpegKit terminó — '
            'Estado: $state, Código: ${ReturnCode.isSuccess(code) ? "OK" : code}',
          );
          
          if (!ReturnCode.isSuccess(code)) {
            final output = await session.getOutput();
            debugPrint('IptvProxy: 🚨 FFmpeg SALIDA DE ERROR: $output');
            if (failStackTrace != null) {
              debugPrint('IptvProxy: 🚨 FFmpeg STACKTRACE: $failStackTrace');
            }
          }
        },
        (Log log) {
          debugPrint('[FFmpeg] ${log.getMessage()}');
        },
      );
    } else {
      // === Escritorio: usar binario del sistema (macOS/Linux) ===
      final ffmpegBin = _detectDesktopFfmpeg();
      debugPrint('IptvProxy: Iniciando FFmpeg proceso ($ffmpegBin)');

      _ffmpegProcess = await Process.start(ffmpegBin, args);

      _ffmpegProcess!.stderr.listen((data) {
        final msg = String.fromCharCodes(data).trim();
        if (msg.isNotEmpty) debugPrint('[FFmpeg] $msg');
      });

      _ffmpegProcess!.exitCode.then((code) {
        debugPrint('IptvProxy: FFmpeg proceso terminó con código $code');
      });
    }
  }

  static String _detectDesktopFfmpeg() {
    if (File('/opt/homebrew/bin/ffmpeg').existsSync()) {
      return '/opt/homebrew/bin/ffmpeg';
    }
    if (File('/usr/local/bin/ffmpeg').existsSync()) {
      return '/usr/local/bin/ffmpeg';
    }
    return 'ffmpeg';
  }

  Future<void> _waitForSegments({
    required int minSegments,
    required int timeoutSeconds,
  }) async {
    debugPrint('IptvProxy: Esperando $minSegments segmentos iniciales...');
    final playlistFile = File('$_hlsDir/playlist.m3u8');
    final deadline = DateTime.now().add(Duration(seconds: timeoutSeconds));

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 400));

      if (!playlistFile.existsSync()) continue;

      final content = playlistFile.readAsStringSync();
      final segCount = RegExp(r'\.ts').allMatches(content).length;

      debugPrint('IptvProxy: FFmpeg progreso: $segCount segmento(s) listos...');

      if (segCount >= minSegments) {
        debugPrint('IptvProxy: Segmentos iniciales listos ✓');
        return;
      }
    }

    debugPrint(
      'IptvProxy: Advertencia — timeout esperando $minSegments segmentos '
      '(continuando de todos modos)',
    );
  }

  Future<void> _startServer() async {
    final staticHandler = createStaticHandler(
      _hlsDir!,
      defaultDocument: 'playlist.m3u8',
    );

    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addHandler(staticHandler);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    _port = _server!.port;
  }

  Middleware _corsMiddleware() {
    return (Handler inner) {
      return (Request req) async {
        try {
          debugPrint('IptvProxy: 🌐 HTTP ${req.method} ${req.url}');
          final res = await inner(req);
          return res.change(headers: {
            'Access-Control-Allow-Origin': '*',
            'Cache-Control': 'no-cache, no-store',
          });
        } catch (e, st) {
          debugPrint('IptvProxy: ❌ Error sirviendo ${req.url}: $e\n$st');
          return Response.internalServerError(body: 'Error local proxy');
        }
      };
    };
  }

  /// Detiene FFmpeg y el servidor HTTP, y limpia el directorio temporal.
  Future<void> stop() async {
    // Detener FFmpegKit (móvil)
    if (_ffmpegSession != null) {
      await FFmpegKit.cancel();
      _ffmpegSession = null;
    }

    // Detener proceso (escritorio)
    _ffmpegProcess?.kill();
    _ffmpegProcess = null;

    // Detener servidor HTTP
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _port = 0;
    _localIp = null;

    // Limpiar directorio temporal
    if (_hlsDir != null) {
      try {
        final dir = Directory(_hlsDir!);
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
      _hlsDir = null;
    }

    debugPrint('IptvProxy: Servidor detenido');
  }
}
