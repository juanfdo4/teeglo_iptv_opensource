import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/channel.dart';
import '../providers/active_playlist_provider.dart';
import 'home_page.dart';
import 'live_tv_page.dart';
import 'movies_page.dart';
import 'series_page.dart';
import 'favorites_page.dart';
import 'playlist_manager_page.dart';

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo_full.png',
              height: 32,
              errorBuilder: (context, error, stackTrace) => const Text('Teeglo IPTV'),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cast),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chromecast feature coming soon')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PlaylistManagerPage()),
              );
            },
          ),
        ],
      ),
      body: activePlaylistAsync.when(
        data: (playlist) => _buildBody(playlist?.channels ?? []),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.live_tv), label: 'Live TV'),
          BottomNavigationBarItem(icon: Icon(Icons.movie), label: 'Películas'),
          BottomNavigationBarItem(icon: Icon(Icons.tv), label: 'Series'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Mi Lista'),
        ],
      ),
    );
  }

  Widget _buildBody(List<Channel> channels) {
    switch (_currentIndex) {
      case 0:
        return HomePage(allChannels: channels);
      case 1:
        return LiveTvPage(channels: channels.where((c) => c.contentType == ContentType.live).toList());
      case 2:
        return MoviesPage(movies: channels.where((c) => c.contentType == ContentType.movie).toList());
      case 3:
        return SeriesPage(seriesEpisodes: channels.where((c) => c.contentType == ContentType.series).toList());
      case 4:
        return const FavoritesPage();
      default:
        return HomePage(allChannels: channels);
    }
  }
}
