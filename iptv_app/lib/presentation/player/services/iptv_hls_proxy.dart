import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Proxy local que hace de puente entre el proveedor IPTV y el Chromecast.
/// Retransmite el stream original inyectando los headers necesarios (User-Agent).
/// Usa un StreamController intermedio para evitar crashes cuando el servidor
/// se cierra mientras el upstream sigue enviando datos.
class IptvHlsProxy {
  HttpServer? _server;
  String? _localIp;
  int _port = 0;

  String? _streamUrl;
  Map<String, String>? _headers;

  // Recursos activos que debemos limpiar al detener
  HttpClient? _activeClient;
  StreamController<List<int>>? _activeController;
  bool _stopped = false;

  String? get baseUrl => _localIp != null ? 'http://$_localIp:$_port' : null;
  String? get playlistUrl => baseUrl != null ? '$baseUrl/playlist.m3u8' : null;
  String? get streamUrl => baseUrl != null ? '$baseUrl/stream.ts' : null;

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
            if (first == 172 && second >= 16 && second <= 31) return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('IptvProxy: Error obteniendo IP - $e');
    }
    return null;
  }

  /// Inicia el servidor HTTP local
  Future<void> start(String streamUrl, Map<String, String> headers) async {
    await stop();

    _streamUrl = streamUrl;
    _headers = headers;
    _stopped = false;

    _localIp = await _getLocalIp();
    if (_localIp == null) {
      throw Exception('IptvProxy: No se pudo obtener la IP local');
    }

    final handler = const Pipeline().addHandler(_handleRequest);
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    _port = _server!.port;

    debugPrint('IptvProxy: Servidor iniciado en http://$_localIp:$_port');
    debugPrint('IptvProxy: URL del Chromecast: $playlistUrl');
  }

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Range',
  };

  Future<Response> _handleRequest(Request request) async {
    if (request.method == 'OPTIONS') {
      return Response.ok('', headers: _corsHeaders);
    }

    if (request.url.path == 'playlist.m3u8') {
      final m3u8 = '#EXTM3U\n'
          '#EXT-X-VERSION:3\n'
          '#EXT-X-TARGETDURATION:86400\n'
          '#EXTINF:86400.0,\n'
          'stream.ts\n';
      return Response.ok(
        m3u8,
        headers: {
          'Content-Type': 'application/x-mpegURL',
          ..._corsHeaders,
          'Cache-Control': 'no-cache',
        },
      );
    }

    if (request.url.path != 'stream.ts') {
      return Response.notFound('Not found');
    }

    if (_streamUrl == null || _stopped) {
      return Response.internalServerError(body: 'No stream configured');
    }

    debugPrint('IptvProxy: Chromecast conectado. Iniciando stream upstream...');

    try {
      final client = HttpClient();
      _activeClient = client;

      final uri = Uri.parse(_streamUrl!);
      final upReq = await client.getUrl(uri);

      if (_headers != null) {
        _headers!.forEach((k, v) => upReq.headers.set(k, v));
      }

      final upRes = await upReq.close();
      debugPrint('IptvProxy: Upstream conectado (status ${upRes.statusCode})');

      if (upRes.statusCode != 200) {
        client.close(force: true);
        _activeClient = null;
        return Response(upRes.statusCode, body: 'Upstream error');
      }

      // Usamos un StreamController intermedio para poder cerrar el flujo
      // de manera segura cuando stop() sea llamado, sin que la VM de Dart
      // intente invocar callbacks ya eliminados.
      final controller = StreamController<List<int>>();
      _activeController = controller;

      // Escuchamos el upstream en un listen separado para poder cancelarlo
      final sub = upRes.listen(
        (data) {
          if (!controller.isClosed && !_stopped) {
            controller.add(data);
          }
        },
        onError: (e) {
          debugPrint('IptvProxy: Error en upstream: $e');
          if (!controller.isClosed) {
            controller.close();
          }
        },
        onDone: () {
          debugPrint('IptvProxy: Upstream terminó');
          if (!controller.isClosed) {
            controller.close();
          }
        },
        cancelOnError: true,
      );

      // Cuando el controller se cierra (por stop() o por fin del stream),
      // cancelamos la suscripción al upstream
      controller.onCancel = () {
        sub.cancel();
        client.close(force: true);
      };

      return Response.ok(
        controller.stream,
        headers: {
          'Content-Type': 'video/mp2t',
          ..._corsHeaders,
          'Cache-Control': 'no-cache',
        },
      );
    } catch (e) {
      debugPrint('IptvProxy: Error proxying stream: $e');
      return Response.internalServerError(body: 'Error: $e');
    }
  }

  Future<void> stop() async {
    _stopped = true;

    // Cerrar el StreamController primero (esto dispara onCancel que cierra el client)
    try {
      if (_activeController != null && !_activeController!.isClosed) {
        await _activeController!.close();
      }
    } catch (_) {}
    _activeController = null;

    // Cerrar el HttpClient por si acaso
    try {
      _activeClient?.close(force: true);
    } catch (_) {}
    _activeClient = null;

    // Finalmente cerrar el servidor HTTP
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _port = 0;
    _streamUrl = null;
    _headers = null;
    debugPrint('IptvProxy: Servidor detenido');
  }
}
