import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/active_playlist_provider.dart';
import '../providers/home_provider.dart';
import '../widgets/channel_list_widget.dart';
import '../widgets/cast_status_indicator.dart';
import 'playlist_manager_page.dart';
import 'favorites_page.dart';

class MainDashboard extends ConsumerStatefulWidget {
  const MainDashboard({super.key});

  @override
  ConsumerState<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends ConsumerState<MainDashboard> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final activePlaylistAsync = ref.watch(activePlaylistProvider);
    final allPlaylistsAsync = ref.watch(localPlaylistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(activePlaylistAsync, allPlaylistsAsync),
        actions: const [
          CastStatusIndicator(),
        ],
      ),
      body: _buildBody(activePlaylistAsync),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Live TV'),
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'VOD'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle(AsyncValue activePlaylistAsync, AsyncValue allPlaylistsAsync) {
    if (_currentIndex == 2) return const Text('Favorites');
    if (_currentIndex == 3) return const Text('Settings & Playlists');

    return activePlaylistAsync.when(
      data: (activePlaylist) {
        if (activePlaylist == null) return const Text('No Playlist');

        return allPlaylistsAsync.when(
          data: (allPlaylists) {
            if (allPlaylists.isEmpty) return Text(activePlaylist.name);

            return PopupMenuButton<String>(
              initialValue: activePlaylist.id,
              onSelected: (String id) {
                ref.read(activePlaylistIdProvider.notifier).setActivePlaylist(id);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(activePlaylist.name),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
              itemBuilder: (BuildContext context) {
                return allPlaylists.map((p) {
                  return PopupMenuItem<String>(
                    value: p.id,
                    child: Text(p.name),
                  );
                }).toList();
              },
            );
          },
          loading: () => Text(activePlaylist.name),
          error: (error, stack) => Text(activePlaylist.name),
        );
      },
      loading: () => const Text('Loading...'),
      error: (error, stack) => const Text('Error'),
    );
  }

  Widget _buildBody(AsyncValue activePlaylistAsync) {
    if (_currentIndex == 2) {
      return const FavoritesPage();
    }
    if (_currentIndex == 3) {
      return const PlaylistManagerPage();
    }

    return activePlaylistAsync.when(
      data: (playlist) {
        if (playlist == null) {
          return const Center(
            child: Text('Please add and select a playlist in the Settings tab.'),
          );
        }

        // Separate Live and VOD
        final liveChannels = <dynamic>[];
        final vodChannels = <dynamic>[];
        final vodKeywords = ['movie', 'pelicula', 'película', 'serie', 'vod', 'cinema', '24/7', 'ppv'];

        for (final channel in playlist.channels) {
          final groupLower = channel.group.toLowerCase();
          bool isVod = false;
          for (final keyword in vodKeywords) {
            if (groupLower.contains(keyword)) {
              isVod = true;
              break;
            }
          }
          if (isVod) {
            vodChannels.add(channel);
          } else {
            liveChannels.add(channel);
          }
        }

        if (_currentIndex == 0) {
          return ChannelListWidget(channels: List.from(liveChannels));
        } else {
          return ChannelListWidget(channels: List.from(vodChannels));
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Error loading playlist: $e')),
    );
  }
}
