import 'package:dartz/dartz.dart';
import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../datasources/playlist_local_data_source.dart';
import '../datasources/playlist_remote_data_source.dart';
import '../models/channel_model.dart';
import '../models/playlist_model.dart';

class PlaylistRepositoryImpl implements PlaylistRepository {
  final PlaylistRemoteDataSource remoteDataSource;
  final PlaylistLocalDataSource localDataSource;

  PlaylistRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, Playlist>> fetchPlaylist(String name, String url) async {
    try {
      final m3uContent = await remoteDataSource.fetchM3uContent(url);
      
      // Basic mock parser
      final channels = _parseM3u(m3uContent);
      
      final playlist = PlaylistModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        url: url,
        channels: channels,
      );

      await localDataSource.savePlaylist(playlist);
      return Right(playlist);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on ParsingException catch (e) {
      return Left(ParsingFailure(e.message));
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Playlist>>> getLocalPlaylists() async {
    try {
      final playlists = await localDataSource.getPlaylists();
      return Right(playlists);
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deletePlaylist(String id) async {
    try {
      await localDataSource.deletePlaylist(id);
      return const Right(null);
    } on LocalStorageException catch (e) {
      return Left(LocalStorageFailure(e.message));
    }
  }

  List<ChannelModel> _parseM3u(String content) {
    // Implement real m3u parsing logic here
    if (!content.contains('#EXTM3U')) {
      throw ParsingException('Invalid M3U format');
    }
    
    // Mock parsing
    return [
      const ChannelModel(
        id: '1',
        name: 'Mock Channel',
        url: 'http://mock.url',
        logoUrl: '',
        group: 'Mock Group',
      ),
    ];
  }
}
