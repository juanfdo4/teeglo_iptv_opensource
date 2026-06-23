import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/active_playlist_provider.dart';
import '../widgets/channel_list_widget.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? 'Live TV' : 
          _currentIndex == 1 ? 'VOD & Series' : 
          _currentIndex == 2 ? 'Favorites' : 
          'Settings & Playlists'
        ),
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
