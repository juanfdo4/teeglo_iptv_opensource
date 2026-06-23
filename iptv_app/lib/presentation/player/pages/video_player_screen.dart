import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../domain/entities/channel.dart';
import '../../home/providers/favorites_provider.dart';

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
      print('MPV_LOG: ${event.level} - ${event.prefix}: ${event.text}');
    });

    player.open(
      Media(
        widget.channel.url,
        httpHeaders: {
          'User-Agent': 'VLC/3.0.9 LibVLC/3.0.9',
          'Connection': 'keep-alive',
        },
      ),
    );
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              ref.watch(favoritesProvider.notifier).isFavorite(widget.channel.id) 
                ? Icons.favorite 
                : Icons.favorite_border,
              color: Colors.red,
            ),
            onPressed: () {
              ref.read(favoritesProvider.notifier).toggleFavorite(widget.channel);
              setState(() {}); // Rebuild icon
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
      body: Center(
        child: Video(controller: controller),
      ),
    );
  }
}
