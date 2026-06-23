import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/favorites_provider.dart';
import '../../player/pages/video_player_screen.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);

    if (favorites.isEmpty) {
      return const Center(
        child: Text('No favorites yet. Tap the heart icon in the player!'),
      );
    }

    return ListView.builder(
      itemCount: favorites.length,
      itemBuilder: (context, index) {
        final channel = favorites[index];
        return ListTile(
          leading: channel.logoUrl.isNotEmpty
              ? Image.network(
                  channel.logoUrl,
                  width: 50,
                  height: 50,
                  errorBuilder: (ctx, err, stack) => const Icon(Icons.favorite, color: Colors.red),
                )
              : const Icon(Icons.favorite, color: Colors.red),
          title: Text(channel.name),
          subtitle: Text(channel.group),
          trailing: IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.grey),
            onPressed: () {
              ref.read(favoritesProvider.notifier).toggleFavorite(channel);
            },
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(channel: channel),
              ),
            );
          },
        );
      },
    );
  }
}
