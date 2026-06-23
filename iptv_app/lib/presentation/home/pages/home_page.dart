import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsyncValue = ref.watch(localPlaylistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teeglo IPTV'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Implement Add Playlist flow
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Add Playlist - Coming Soon')),
              );
            },
          ),
        ],
      ),
      body: playlistsAsyncValue.when(
        data: (playlists) {
          if (playlists.isEmpty) {
            return const Center(child: Text('No playlists found. Add one!'));
          }
          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return ListTile(
                title: Text(playlist.name),
                subtitle: Text('${playlist.channels.length} channels'),
                onTap: () {
                  // Navigate to channels page
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
