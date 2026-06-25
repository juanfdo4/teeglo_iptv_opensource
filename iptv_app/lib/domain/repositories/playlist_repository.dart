import 'package:dartz/dartz.dart';
import '../../core/error/failures.dart';
import '../entities/playlist.dart';

abstract class PlaylistRepository {
  /// Fetches a playlist from the given [url] and optionally saves it locally with [name].
  Future<Either<Failure, Playlist>> fetchPlaylist(
    String name,
    String url, {
    void Function(int count, int total)? onReceiveProgress,
    void Function()? onProcessingStarted,
    void Function(int count)? onChannelsParsed,
  });

  /// Adds a playlist directly from M3U string content (useful for local files).
  Future<Either<Failure, Playlist>> addPlaylistFromContent(
    String name,
    String content, {
    void Function()? onProcessingStarted,
    void Function(int count)? onChannelsParsed,
  });

  /// Retrieves all locally saved playlists.
  Future<Either<Failure, List<Playlist>>> getLocalPlaylists();

  /// Deletes a locally saved playlist by [id].
  Future<Either<Failure, void>> deletePlaylist(String id);
}
