import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'home_provider.dart';
import '../../../domain/entities/playlist.dart';

final activePlaylistIdProvider = NotifierProvider<ActivePlaylistNotifier, String?>(() {
  return ActivePlaylistNotifier();
});

class ActivePlaylistNotifier extends Notifier<String?> {
  @override
  String? build() {
    return Hive.box('settings').get('active_playlist_id') as String?;
  }

  void setActivePlaylist(String id) {
    Hive.box('settings').put('active_playlist_id', id);
    state = id;
  }
}

final activePlaylistProvider = Provider<AsyncValue<Playlist?>>((ref) {
  final activeId = ref.watch(activePlaylistIdProvider);
  final playlistsAsync = ref.watch(localPlaylistsProvider);

  return playlistsAsync.whenData((playlists) {
    if (playlists.isEmpty) return null;
    
    // If no active ID is set, or if it doesn't exist, fallback to the first playlist
    if (activeId == null) return playlists.first;
    
    try {
      return playlists.firstWhere((p) => p.id == activeId);
    } catch (_) {
      return playlists.first;
    }
  });
});
