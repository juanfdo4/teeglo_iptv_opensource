import 'dart:isolate';
import 'package:dartz/dartz.dart';
import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/repositories/playlist_repository.dart';
import '../datasources/playlist_local_data_source.dart';
import '../datasources/playlist_remote_data_source.dart';
import '../models/playlist_model.dart';
import 'package:flutter/foundation.dart';
import '../utils/m3u_parser.dart';

class PlaylistRepositoryImpl implements PlaylistRepository {
  final PlaylistRemoteDataSource remoteDataSource;
  final PlaylistLocalDataSource localDataSource;

  PlaylistRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<Either<Failure, Playlist>> fetchPlaylist(
    String name,
    String url, {
    void Function(int count, int total)? onReceiveProgress,
    void Function()? onProcessingStarted,
    void Function(int count)? onChannelsParsed,
  }) async {
    try {
      final m3uContent = await remoteDataSource.fetchM3uContent(url, onReceiveProgress: onReceiveProgress);
      
      onProcessingStarted?.call();
      
      final receivePort = ReceivePort();
      receivePort.listen((message) {
        if (message is int) {
          onChannelsParsed?.call(message);
        }
      });

      // Parsear la lista pesada en un hilo secundario
      final channels = await compute(M3uParser.parseWithProgress, ParseRequest(m3uContent, receivePort.sendPort));
      
      receivePort.close();
      
      if (channels.isEmpty) {
        throw ParsingException('No channels found or invalid format');
      }
      
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
  Future<Either<Failure, Playlist>> addPlaylistFromContent(
    String name,
    String content, {
    void Function()? onProcessingStarted,
    void Function(int count)? onChannelsParsed,
  }) async {
    try {
      onProcessingStarted?.call();
      
      final receivePort = ReceivePort();
      receivePort.listen((message) {
        if (message is int) {
          onChannelsParsed?.call(message);
        }
      });

      final channels = await compute(M3uParser.parseWithProgress, ParseRequest(content, receivePort.sendPort));
      
      receivePort.close();
      
      if (channels.isEmpty) {
        throw ParsingException('No channels found or invalid format');
      }
      
      final playlist = PlaylistModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        url: 'local',
        channels: channels,
      );

      await localDataSource.savePlaylist(playlist);
      return Right(playlist);
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
}
