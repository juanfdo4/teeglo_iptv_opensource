import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/channel.dart';
import '../../../core/theme/app_theme.dart';
import '../../player/pages/video_player_screen.dart';
import '../providers/favorites_provider.dart';
import '../widgets/content_carousel.dart';

class HomePage extends ConsumerWidget {
  final List<Channel> allChannels;

  const HomePage({super.key, required this.allChannels});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (allChannels.isEmpty) {
      return const Center(child: Text('No content available.'));
    }

    // Categorize content
    final liveChannels = allChannels.where((c) => c.contentType == ContentType.live).toList();
    final movies = allChannels.where((c) => c.contentType == ContentType.movie).toList();
    final series = allChannels.where((c) => c.contentType == ContentType.series).toList();

    // Select a hero channel (first movie, or first series, or first live)
    final heroChannel = movies.isNotEmpty ? movies.first : (series.isNotEmpty ? series.first : liveChannels.first);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner
          _buildHeroBanner(context, ref, heroChannel),
          const SizedBox(height: 24),
          
          // Carousels
          if (liveChannels.isNotEmpty)
            ContentCarousel(
              title: '🔴 En Vivo Ahora',
              channels: liveChannels.take(15).toList(),
            ),
          
          if (movies.isNotEmpty)
            ContentCarousel(
              title: '🎬 Estrenos Recomendados',
              channels: movies.take(15).toList(),
            ),
            
          if (series.isNotEmpty)
            ContentCarousel(
              title: '📺 Series Populares',
              channels: series.take(15).toList(),
            ),

          // Group-based carousels (e.g., NETFLIX, COLOMBIA)
          ..._buildGroupCarousels(allChannels),
          
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context, WidgetRef ref, Channel channel) {
    final isFav = ref.watch(favoritesProvider).any((c) => c.id == channel.id);

    return Stack(
      children: [
        // Background Image
        Container(
          height: 400,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            image: channel.logoUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(channel.logoUrl),
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  )
                : null,
          ),
        ),
        
        // Gradient overlay to fade into background
        Container(
          height: 400,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.bgDark.withOpacity(0.1),
                AppTheme.bgDark.withOpacity(0.5),
                AppTheme.bgDark,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),

        // Content
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Column(
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  channel.seriesName ?? channel.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 10, offset: Offset(0, 2)),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 12),
              
              // Metadata tags
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (channel.year != null) ...[
                    Text(channel.year!, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: Colors.white54)),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    channel.contentType == ContentType.live ? 'En Vivo' : (channel.contentType == ContentType.movie ? 'Película' : 'Serie'),
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  const Text('•', style: TextStyle(color: Colors.white54)),
                  const SizedBox(width: 8),
                  Text(channel.group, style: const TextStyle(color: Colors.white70)),
                ],
              ).animate().fadeIn(delay: 200.ms),
              
              const SizedBox(height: 20),
              
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play Button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(channel: channel),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow, color: Colors.black),
                    label: const Text('Reproducir', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // My List Button
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(favoritesProvider.notifier).toggleFavorite(channel);
                    },
                    icon: Icon(isFav ? Icons.check : Icons.add, color: Colors.white),
                    label: const Text('Mi Lista', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms).scale(),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGroupCarousels(List<Channel> channels) {
    // Group channels by their 'group' attribute
    final grouped = <String, List<Channel>>{};
    for (final c in channels) {
      grouped.putIfAbsent(c.group, () => []).add(c);
    }

    // Sort groups by size (largest first)
    final sortedGroups = grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    final widgets = <Widget>[];
    // Take top 5 groups to avoid too many carousels
    for (final entry in sortedGroups.take(5)) {
      if (entry.key.isNotEmpty && entry.key.toLowerCase() != 'uncategorized') {
        widgets.add(ContentCarousel(
          title: entry.key,
          channels: entry.value.take(15).toList(),
        ));
      }
    }
    return widgets;
  }
}
