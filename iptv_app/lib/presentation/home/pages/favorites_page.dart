import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/channel.dart';
import '../providers/favorites_provider.dart';
import '../providers/active_playlist_provider.dart';
import '../widgets/content_card.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allFavorites = ref.watch(favoritesProvider);
    final activePlaylistAsync = ref.watch(activePlaylistProvider);

    if (allFavorites.isEmpty) {
      return const Center(child: Text('Aún no has agregado nada a tu lista'));
    }

    List<Channel> currentFavorites = [];
    
    activePlaylistAsync.whenData((playlist) {
      if (playlist != null) {
        final playlistChannelIds = Set.from(playlist.channels.map((c) => c.id));
        currentFavorites = allFavorites.where((f) => playlistChannelIds.contains(f.id)).toList();
      }
    });

    if (currentFavorites.isEmpty) {
      return const Center(child: Text('No hay favoritos en esta lista'));
    }

    // Separate into categories for better display
    final live = currentFavorites.where((c) => c.contentType == ContentType.live).toList();
    final movies = currentFavorites.where((c) => c.contentType == ContentType.movie).toList();
    final series = currentFavorites.where((c) => c.contentType == ContentType.series).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Mi Lista', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          if (live.isNotEmpty) _buildSection('Canales Guardados', live),
          if (movies.isNotEmpty) _buildSection('Películas Guardadas', movies),
          if (series.isNotEmpty) _buildSection('Series Guardadas', series),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Channel> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70)),
        ),
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(), // Scroll handled by SingleChildScrollView
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return ContentCard(channel: items[index]);
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
