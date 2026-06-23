import 'package:hive_flutter/hive_flutter.dart';
import '../../core/error/exceptions.dart';
import '../models/playlist_model.dart';

abstract class PlaylistLocalDataSource {
  Future<void> savePlaylist(PlaylistModel playlist);
  Future<List<PlaylistModel>> getPlaylists();
  Future<void> deletePlaylist(String id);
}

class PlaylistLocalDataSourceImpl implements PlaylistLocalDataSource {
  final Box _box = Hive.box('playlists');

  @override
  Future<void> savePlaylist(PlaylistModel playlist) async {
    try {
      await _box.put(playlist.id, playlist.toJson());
    } catch (e) {
      throw LocalStorageException();
    }
  }

  @override
  Future<List<PlaylistModel>> getPlaylists() async {
    try {
      final List<PlaylistModel> playlists = [];
      for (var key in _box.keys) {
        final Map<dynamic, dynamic>? data = _box.get(key);
        if (data != null) {
          // Convert Map<dynamic, dynamic> to Map<String, dynamic>
          final jsonMap = Map<String, dynamic>.from(data);
          playlists.add(PlaylistModel.fromJson(jsonMap));
        }
      }
      return playlists;
    } catch (e) {
      throw LocalStorageException();
    }
  }

  @override
  Future<void> deletePlaylist(String id) async {
    try {
      await _box.delete(id);
    } catch (e) {
      throw LocalStorageException();
    }
  }
}
