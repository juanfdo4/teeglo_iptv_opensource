// test_cast.dart
// New approach: FFmpeg-based HLS segmenter for Chromecast casting.
// FFmpeg pulls the IPTV stream, creates proper HLS segments in a temp dir,
// and we serve them via a simple HTTP server for the Chromecast to fetch.
// ignore_for_file: avoid_print
import 'dart:async';
import 'dart:io';
import 'package:dart_cast/dart_cast.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

class DirectMediaTransformer implements MediaTransformer {
  const DirectMediaTransformer();
  @override
  Future<TransformedMedia> transform(CastMedia media, MediaProxy proxy) async {
    return TransformedMedia(proxyUrl: media.url, effectiveType: media.type);
  }
}

class FfmpegHlsProxy {
  final String ffmpegPath;
  final String hlsDir;
  Process? _ffmpegProcess;
  HttpServer? _server;
  String? _localIp;
  int _port = 0;

  FfmpegHlsProxy({
    this.ffmpegPath = '/opt/homebrew/bin/ffmpeg',
    required this.hlsDir,
  });

  String? get baseUrl => _localIp != null ? 'http://$_localIp:$_port' : null;
  String? get playlistUrl => baseUrl != null ? '$baseUrl/playlist.m3u8' : null;

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
      print('Error getting local IP: $e');
    }
    return null;
  }



  Future<void> start(String streamUrl, Map<String, String> headers) async {
    await stop();

    _localIp = await _getLocalIp();
    if (_localIp == null) throw Exception('Could not get local IP');

    // Clean HLS dir
    final dir = Directory(hlsDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);

    // IMPORTANT: Pass the ORIGINAL URL to FFmpeg so it can follow
    // redirects itself. Pre-resolving causes token expiry (signed auth URLs
    // are short-lived — by the time FFmpeg opens the pre-resolved URL it's gone).
    // FFmpeg has built-in redirect following via -follow_redirects.
    print('Starting FFmpeg with original URL (letting FFmpeg follow redirects)...');
    print('URL: $streamUrl');

    // Build FFmpeg args.
    // CRITICAL: Source stream is interlaced H.264 (yuv420p, top first).
    // Chromecast Default Media Receiver does NOT support interlaced H.264.
    // We must transcode with yadif deinterlacing + Chromecast-compatible profile.
    //
    // Chromecast video requirements:
    //   - H.264 Baseline/Main/High profile, up to level 4.1
    //   - Progressive (non-interlaced) frames
    //   - AAC-LC audio, max 2 channels
    final userAgent = headers['User-Agent'] ?? 'VLC/3.0.9 LibVLC/3.0.9';
    final args = [
      '-loglevel', 'info',
      '-reconnect', '1',
      '-reconnect_at_eof', '1',
      '-reconnect_streamed', '1',
      '-reconnect_delay_max', '5',
      '-user_agent', userAgent,
      '-i', streamUrl,
      // Video: transcode with deinterlace → Chromecast-compatible H.264
      '-vf', 'yadif=mode=1',          // yadif mode=1: send frame + field (bob deinterlace)
      '-c:v', 'libx264',
      '-preset', 'veryfast',           // fast encode, good quality
      '-profile:v', 'high',
      '-level:v', '4.1',
      '-pix_fmt', 'yuv420p',
      '-g', '50',                      // keyframe every 2s at 25fps (aids HLS seeking)
      '-sc_threshold', '0',
      // Audio: AAC-LC stereo for Chromecast
      '-c:a', 'aac',
      '-b:a', '128k',
      '-ac', '2',
      '-ar', '44100',
      // HLS output
      '-f', 'hls',
      '-hls_time', '4',
      '-hls_list_size', '6',
      '-hls_flags', 'delete_segments+append_list',
      '-hls_allow_cache', '0',
      '-hls_segment_type', 'mpegts',
      '-hls_segment_filename', '$hlsDir/seg%05d.ts',
      '$hlsDir/playlist.m3u8',
    ];

    print('Starting FFmpeg...');
    _ffmpegProcess = await Process.start(ffmpegPath, args);

    // Forward FFmpeg stderr to console for diagnostics
    _ffmpegProcess!.stderr.listen((data) {
      final msg = String.fromCharCodes(data).trim();
      if (msg.isNotEmpty) print('[FFmpeg] $msg');
    });

    _ffmpegProcess!.exitCode.then((code) {
      print('[FFmpeg] exited with code $code');
    });

    // Wait until playlist.m3u8 exists and has at least 3 segments ready
    print('Waiting for FFmpeg to produce initial segments...');
    final playlistFile = File('$hlsDir/playlist.m3u8');
    final startWait = DateTime.now();
    while (true) {
      if (DateTime.now().difference(startWait) > const Duration(seconds: 30)) {
        throw Exception('Timeout waiting for FFmpeg to produce playlist');
      }
      await Future.delayed(const Duration(milliseconds: 300));
      if (!playlistFile.existsSync()) continue;
      final content = playlistFile.readAsStringSync();
      final segCount = RegExp(r'\.ts').allMatches(content).length;
      print('  FFmpeg progress: $segCount segment(s) in playlist...');
      if (segCount >= 3) {
        print('Initial segments ready!');
        break;
      }
    }

    // Start HTTP server to serve the HLS dir
    final staticHandler = createStaticHandler(hlsDir, defaultDocument: 'playlist.m3u8');
    final handler = const Pipeline().addMiddleware(_corsMiddleware()).addHandler(staticHandler);
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    _port = _server!.port;

    print('HLS server started at http://$_localIp:$_port');
    print('Chromecast playlist URL: $playlistUrl');
  }

  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request req) async {
        print('HTTP: ${req.method} ${req.url}');
        final response = await handler(req);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Cache-Control': 'no-cache, no-store',
        });
      };
    };
  }

  Future<void> stop() async {
    _ffmpegProcess?.kill();
    _ffmpegProcess = null;
    await _server?.close(force: true);
    _server = null;
    _port = 0;
    _localIp = null;
  }
}

Future<void> main() async {
  CastLogger.setCallback((level, message) {
    print('[$level] $message');
  });

  const targetIp = '192.168.1.6';
  const targetPort = 8009;
  const iptvUrl =
      'http://ultratvsv.site:80/play/Ut6nvSuJBpnefuevKi1tR9F30mgxL9Y3h-3e5wI0U0-6qNUBFHpzFKV5q9hT_kcN';
  const hlsDir = '/tmp/iptv_hls';

  print('=== FFmpeg HLS Chromecast Test ===');
  print('Stream: $iptvUrl');
  print('Device: $targetIp:$targetPort');

  final proxy = FfmpegHlsProxy(hlsDir: hlsDir);

  try {
    // Step 1: Start FFmpeg HLS proxy
    await proxy.start(iptvUrl, {
      'User-Agent': 'VLC/3.0.9 LibVLC/3.0.9',
      'Connection': 'keep-alive',
    });

    final castUrl = proxy.playlistUrl!;
    print('✅ Local HLS URL: $castUrl');

    // Step 2: Set up CastService with direct device (skip mDNS to save time)
    final service = CastService(
      discoveryProviders: [ChromecastDiscoveryProvider()],
      sessionFactory: (device) => ChromecastSession(
        device: device,
        mediaTransformer: const DirectMediaTransformer(),
        enableReceiverDebugNamespaces: true,
      ),
    );

    // Try mDNS discovery with timeout, fallback to manual IP
    CastDevice? device;
    print('Searching for Chromecast via mDNS (5s)...');
    try {
      final devices = await service
          .startDiscovery(timeout: const Duration(seconds: 5))
          .expand((list) => list)
          .where((d) => d.address.address == targetIp)
          .first
          .timeout(const Duration(seconds: 6));
      device = devices;
      print('✅ mDNS found: ${device.name} at $targetIp');
    } catch (_) {
      // Fallback: create device manually with known IP
      print('⚠️  mDNS timeout — using manual device at $targetIp:$targetPort');
      device = CastDevice(
        id: 'chromecast-manual',
        name: 'Chromecast',
        protocol: CastProtocol.chromecast,
        address: InternetAddress(targetIp),
        port: targetPort,
      );
    }

    // Step 3: Connect and load
    final session = await service.connect(device);
    print('🔗 Connected! Loading HLS stream via FFmpeg proxy...');
    print('   URL: $castUrl');

    await session.loadMedia(CastMedia(
      url: castUrl,
      type: CastMediaType.hls,
      title: 'IPTV Live (FFmpeg HLS)',
      httpHeaders: const {},
    ));

    print('🎉 Stream loaded! Watching for 90 seconds...');
    await Future.delayed(const Duration(seconds: 90));

    await session.disconnect();
    print('🔚 Done');
  } catch (e, st) {
    print('❗ Error: $e');
    print(st);
  } finally {
    await proxy.stop();
  }
}
