import '../../core/error/exceptions.dart';
import '../models/playlist_model.dart';

abstract class PlaylistLocalDataSource {
  Future<void> savePlaylist(PlaylistModel playlist);
  Future<List<PlaylistModel>> getPlaylists();
  Future<void> deletePlaylist(String id);
}

class PlaylistLocalDataSourceImpl implements PlaylistLocalDataSource {
  // In a real app, inject Hive, Isar, or SharedPreferences here
  final List<PlaylistModel> _mockStorage = [];

  @override
  Future<void> savePlaylist(PlaylistModel playlist) async {
    try {
      _mockStorage.add(playlist);
    } catch (e) {
      throw LocalStorageException();
    }
  }

  @override
  Future<List<PlaylistModel>> getPlaylists() async {
    try {
      return _mockStorage;
    } catch (e) {
      throw LocalStorageException();
    }
  }

  @override
  Future<void> deletePlaylist(String id) async {
    try {
      _mockStorage.removeWhere((element) => element.id == id);
    } catch (e) {
      throw LocalStorageException();
    }
  }
}
