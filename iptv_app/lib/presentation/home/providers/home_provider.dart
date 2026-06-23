import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/datasources/playlist_local_data_source.dart';
import '../../../data/datasources/playlist_remote_data_source.dart';
import '../../../data/repositories/playlist_repository_impl.dart';
import '../../../domain/entities/playlist.dart';
import '../../../domain/repositories/playlist_repository.dart';

final dioProvider = Provider<Dio>((ref) {
  return Dio();
});

final playlistRemoteDataSourceProvider = Provider<PlaylistRemoteDataSource>((ref) {
  return PlaylistRemoteDataSourceImpl(dio: ref.watch(dioProvider));
});

final playlistLocalDataSourceProvider = Provider<PlaylistLocalDataSource>((ref) {
  return PlaylistLocalDataSourceImpl();
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepositoryImpl(
    remoteDataSource: ref.watch(playlistRemoteDataSourceProvider),
    localDataSource: ref.watch(playlistLocalDataSourceProvider),
  );
});

final localPlaylistsProvider = FutureProvider<List<Playlist>>((ref) async {
  final repository = ref.watch(playlistRepositoryProvider);
  final result = await repository.getLocalPlaylists();
  
  return result.fold(
    (failure) => throw Exception(failure.message),
    (playlists) => playlists,
  );
});
