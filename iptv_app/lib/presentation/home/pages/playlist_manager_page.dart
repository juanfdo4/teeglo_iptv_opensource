import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';
import '../providers/active_playlist_provider.dart';
import '../widgets/add_playlist_dialog.dart';

class PlaylistManagerPage extends ConsumerWidget {
  const PlaylistManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsyncValue = ref.watch(localPlaylistsProvider);
    final activePlaylistId = ref.watch(activePlaylistIdProvider);

    return Scaffold(
      body: playlistsAsyncValue.when(
        data: (playlists) {
          if (playlists.isEmpty) {
            return const Center(child: Text('No playlists found. Add one!'));
          }
          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              final isActive = activePlaylistId == playlist.id || (activePlaylistId == null && index == 0);
              
              return ListTile(
                leading: Icon(
                  isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isActive ? Theme.of(context).primaryColor : Colors.grey,
                ),
                title: Text(playlist.name),
                subtitle: Text('${playlist.channels.length} channels'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (playlist.url.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Actualizando ${playlist.name}...')),
                          );
                          final result = await ref.read(playlistRepositoryProvider).fetchPlaylist(playlist.name, playlist.url);
                          
                          if (context.mounted) {
                            result.fold(
                              (failure) => ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: ${failure.message}')),
                              ),
                              (_) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${playlist.name} actualizada con éxito!')),
                                );
                                ref.invalidate(localPlaylistsProvider);
                              },
                            );
                          }
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await ref.read(playlistRepositoryProvider).deletePlaylist(playlist.id);
                        ref.invalidate(localPlaylistsProvider);
                      },
                    ),
                  ],
                ),
                onTap: () {
                  ref.read(activePlaylistIdProvider.notifier).setActivePlaylist(playlist.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${playlist.name} set as active playlist')),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddPlaylistDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
