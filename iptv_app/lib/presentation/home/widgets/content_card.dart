import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/channel.dart';
import '../../../core/theme/app_theme.dart';
import '../../player/pages/video_player_screen.dart';
import '../../player/providers/playback_progress_provider.dart';
import '../providers/favorites_provider.dart';

class ContentCard extends ConsumerWidget {
  final Channel channel;
  final VoidCallback? onTap;

  const ContentCard({
    super.key,
    required this.channel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFav = ref.watch(favoritesProvider).any((c) => c.id == channel.id);
    ref.watch(playbackProgressProvider); // Rebuilds when state (int) changes
    final progressService = ref.read(playbackProgressProvider.notifier);
    final isWatched = progressService.isWatched(channel.url);
    final progress = progressService.getProgress(channel.url);
    final duration = progressService.getDuration(channel.url);
    
    double progressPercent = 0.0;
    if (progress != null && duration != null && duration.inSeconds > 0) {
      progressPercent = progress.inSeconds / duration.inSeconds;
    }

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.bgSurface,
          builder: (context) {
            return SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: Icon(isWatched ? Icons.remove_circle_outline : Icons.check_circle_outline, color: Colors.white),
                    title: Text(isWatched ? 'Marcar como no visto' : 'Marcar como visto', style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      if (isWatched) {
                        ref.read(playbackProgressProvider.notifier).markAsUnwatched(channel.url);
                      } else {
                        ref.read(playbackProgressProvider.notifier).markAsWatched(channel.url);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      onTap: onTap ?? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(channel: channel),
          ),
        );
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: AppTheme.bgSurface,
          image: channel.logoUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(channel.logoUrl),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  onError: (exception, stackTrace) => const Icon(Icons.tv),
                )
              : null,
        ),
        child: Stack(
          children: [
            // Fallback icon if no image
            if (channel.logoUrl.isEmpty)
              const Center(child: Icon(Icons.tv, color: Colors.white54, size: 40)),
            
            // Dark gradient overlay at the bottom for text readability
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 60,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.8),
                      Colors.black,
                    ],
                  ),
                ),
              ),
            ),
            
            // Content Info
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (channel.contentType == ContentType.live)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.liveIndicator,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'EN VIVO',
                        style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  if (channel.contentType == ContentType.series && channel.season != null && channel.episode != null)
                    Text(
                      'T${channel.season} E${channel.episode}',
                      style: const TextStyle(color: AppTheme.teegloCyan, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  Text(
                    channel.name,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Favorite toggle button
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  ref.read(favoritesProvider.notifier).toggleFavorite(channel);
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        !isFav ? 'Agregado a favoritos' : 'Eliminado de favoritos',
                      ),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border, 
                    color: isFav ? AppTheme.liveIndicator : Colors.white, 
                    size: 16,
                  ),
                ),
              ),
            ),
            
            // Watched indicator
            if (isWatched)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.greenAccent, size: 14),
                ),
              ),

            // Progress bar at the very bottom
            if (!isWatched && progressPercent > 0)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: progressPercent,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                  minHeight: 4,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
