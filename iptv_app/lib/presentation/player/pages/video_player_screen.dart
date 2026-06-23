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
  late final Player player = Player();
  late final VideoController controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    player.open(Media(widget.channel.url));
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
        title: Text(
          widget.channel.name,
          style: const TextStyle(color: Colors.white),
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
