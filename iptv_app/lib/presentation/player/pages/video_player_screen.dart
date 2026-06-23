import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../domain/entities/channel.dart';
import '../../home/providers/favorites_provider.dart';
import '../providers/cast_provider.dart';
import '../providers/playback_progress_provider.dart';
import '../widgets/cast_player_controls.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final Channel channel;

  const VideoPlayerScreen({super.key, required this.channel});

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final Player player = Player(
    configuration: const PlayerConfiguration(
      bufferSize: 32 * 1024 * 1024,
      logLevel: MPVLogLevel.debug,
    ),
  );
  late final VideoController controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    player.stream.log.listen((event) {
      debugPrint('MPV_LOG: ${event.level} - ${event.prefix}: ${event.text}');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final castState = ref.read(castNotifierProvider);
      final isCasting = castState.session != null;
      
      final progressService = ref.read(playbackProgressProvider);
      final savedProgress = progressService.getProgress(widget.channel.url);

      if (isCasting) {
        // Si ya estamos transmitiendo, enviar el nuevo video al Chromecast
        await ref.read(castNotifierProvider.notifier).castUrl(widget.channel.url, widget.channel.name);
        
        if (savedProgress != null && context.mounted) {
          _showResumeDialog(savedProgress, () {
            ref.read(castNotifierProvider).session?.seek(savedProgress);
          });
        }
      }

      // Preparar el reproductor local (pausado si estamos transmitiendo)
      player.open(
        Media(
          widget.channel.url,
          httpHeaders: {
            'User-Agent': 'VLC/3.0.9 LibVLC/3.0.9',
            'Connection': 'keep-alive',
          },
        ),
        play: !isCasting && savedProgress == null, 
      );
      
      if (!isCasting && savedProgress != null && context.mounted) {
        _showResumeDialog(savedProgress, () {
          player.seek(savedProgress);
          player.play();
        });
      }

      // Guardar progreso localmente mientras se reproduce
      player.stream.position.listen((position) {
        final duration = player.state.duration;
        if (!ref.read(castNotifierProvider).session.hashCode.isNaN && duration.inSeconds > 0) {
          progressService.saveProgress(widget.channel.url, position, duration);
        }
      });
    });
  }

  void _showResumeDialog(Duration savedProgress, VoidCallback onResume) {
    String format(Duration d) {
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
      String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
      if (d.inHours > 0) return "${d.inHours}:$twoDigitMinutes:$twoDigitSeconds";
      return "$twoDigitMinutes:$twoDigitSeconds";
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Continuar viendo', style: TextStyle(color: Colors.white)),
        content: Text('¿Deseas continuar desde ${format(savedProgress)}?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(playbackProgressProvider).clearProgress(widget.channel.url);
              if (ref.read(castNotifierProvider).session == null) {
                player.play(); // Start from 0 locally
              }
            },
            child: const Text('Desde el principio', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onResume();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Continuar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  void _showCastDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final devicesAsync = ref.watch(castDevicesProvider);
            
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transmitir a...',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  devicesAsync.when(
                    data: (devices) {
                      if (devices.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Text('Buscando dispositivos en la red...', style: TextStyle(color: Colors.white70)),
                          ),
                        );
                      }
                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return ListTile(
                            leading: const Icon(Icons.tv, color: Colors.white),
                            title: Text(device.name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(device.address.address, style: const TextStyle(color: Colors.white54)),
                            onTap: () async {
                              Navigator.pop(context);
                              // Pause local playback
                              player.pause();
                              
                              // Connect to cast device
                              final castNotifier = ref.read(castNotifierProvider.notifier);
                              await castNotifier.connectToDevice(device);
                              await castNotifier.castUrl(widget.channel.url, widget.channel.name);
                            },
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(height: 16),
                  if (ref.watch(castNotifierProvider).session != null)
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.read(castNotifierProvider.notifier).disconnect();
                        player.play(); // Resume local playback
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.cast_connected),
                      label: const Text('Desconectar'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final castState = ref.watch(castNotifierProvider);
    final isCasting = castState.session != null;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.channel.name,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            StreamBuilder<Duration>(
              stream: player.stream.duration,
              builder: (context, snapshot) {
                final duration = snapshot.data ?? Duration.zero;
                if (duration.inMinutes > 0) {
                  return Text(
                    '🎬 Archivo • ${duration.inMinutes} min',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  );
                } else {
                  return const Text(
                    '🔴 EN VIVO',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isCasting ? Icons.cast_connected : Icons.cast,
              color: isCasting ? Colors.blue : Colors.white,
            ),
            onPressed: () => _showCastDialog(context),
          ),
          IconButton(
            icon: Icon(
              ref.watch(favoritesProvider).any((c) => c.id == widget.channel.id)
                ? Icons.favorite 
                : Icons.favorite_border,
              color: Colors.red,
            ),
            onPressed: () {
              ref.read(favoritesProvider.notifier).toggleFavorite(widget.channel); 
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ref.read(favoritesProvider.notifier).isFavorite(widget.channel.id)
                        ? 'Added to favorites'
                        : 'Removed from favorites'
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          final errorMessage = castState.errorMessage;

          // Si hay error de casting, mostrar mensaje y reanudar video local
          if (errorMessage != null && !isCasting) {
            // Reanudar el video local automáticamente si hay error
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!player.state.playing) player.play();
            });
            return Stack(
              children: [
                Video(controller: controller),
                Positioned(
                  bottom: 60,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                          onPressed: () => ref.read(castNotifierProvider.notifier).disconnect(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          if (isCasting) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cast_connected, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  'Transmitiendo a la TV...',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 40),
                CastPlayerControls(session: castState.session!),
              ],
            );
          }

          return Video(controller: controller);
        },
      ),
    );
  }
}
