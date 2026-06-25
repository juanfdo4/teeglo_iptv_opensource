import 'dart:convert';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/playlist_model.dart';

class BackupService {
  static Future<void> exportData(BuildContext context) async {
    try {
      final playlistsBox = Hive.box('playlists');
      final favoritesBox = Hive.box('favorites');
      final progressBox = Hive.box('playback_progress');

      // Solo guardamos la metadata de las listas, vaciamos los canales
      final List<Map<String, dynamic>> playlistsBackup = [];
      for (var key in playlistsBox.keys) {
        final data = playlistsBox.get(key);
        if (data != null) {
          final jsonMap = Map<String, dynamic>.from(data as Map);
          final playlist = PlaylistModel.fromJson(jsonMap);
          // Creamos un clon pero con canales vacíos para no saturar el JSON
          final cleanPlaylist = PlaylistModel(
            id: playlist.id,
            name: playlist.name,
            url: playlist.url,
            channels: const [],
          );
          playlistsBackup.add(cleanPlaylist.toJson());
        }
      }

      // Guardamos los favoritos
      final Map<String, dynamic> favoritesBackup = {};
      for (var key in favoritesBox.keys) {
        final data = favoritesBox.get(key);
        if (data != null) {
          favoritesBackup[key.toString()] = Map<String, dynamic>.from(data as Map);
        }
      }

      // Guardamos el progreso de reproducción
      final Map<String, dynamic> progressBackup = {};
      for (var key in progressBox.keys) {
        progressBackup[key.toString()] = progressBox.get(key);
      }

      final Map<String, dynamic> backupData = {
        'version': 1,
        'playlists': playlistsBackup,
        'favorites': favoritesBackup,
        'progress': progressBackup,
      };

      final jsonString = jsonEncode(backupData);

      // Guardar en un archivo temporal para compartirlo
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/teeglo_backup.json');
      await file.writeAsString(jsonString);

      // Compartir el archivo (Abre el diálogo nativo de iOS/Android)
      if (context.mounted) {
        final xFile = XFile(file.path, mimeType: 'application/json');
        // ignore: deprecated_member_use
        await Share.shareXFiles([xFile], text: 'Backup Teeglo IPTV');
      }

    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  static Future<bool> importData(BuildContext context) async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'JSONs',
        extensions: <String>['json'],
      );
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);

      if (file == null) return false;

      final jsonString = await file.readAsString();
      final Map<String, dynamic> backupData = jsonDecode(jsonString);

      if (backupData['version'] != 1) {
        throw Exception('Versión de respaldo no compatible');
      }

      final playlistsBox = Hive.box('playlists');
      final favoritesBox = Hive.box('favorites');
      final progressBox = Hive.box('playback_progress');

      // Importar playlists
      final playlistsBackup = backupData['playlists'] as List<dynamic>? ?? [];
      for (var pData in playlistsBackup) {
        final mapData = Map<String, dynamic>.from(pData);
        await playlistsBox.put(mapData['id'], mapData);
      }

      // Importar favoritos
      final favoritesBackup = backupData['favorites'] as Map<String, dynamic>? ?? {};
      for (var key in favoritesBackup.keys) {
        await favoritesBox.put(key, favoritesBackup[key]);
      }

      // Importar progreso
      final progressBackup = backupData['progress'] as Map<String, dynamic>? ?? {};
      for (var key in progressBackup.keys) {
        await progressBox.put(key, progressBackup[key]);
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e')),
        );
      }
      return false;
    }
  }
}
