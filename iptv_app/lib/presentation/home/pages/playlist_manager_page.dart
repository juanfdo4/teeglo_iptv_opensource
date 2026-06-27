import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/home_provider.dart';
import '../providers/active_playlist_provider.dart';
import '../widgets/add_playlist_dialog.dart';
import '../../../data/services/backup_service.dart';

class PlaylistManagerPage extends ConsumerWidget {
  const PlaylistManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsyncValue = ref.watch(localPlaylistsProvider);
    final activePlaylistId = ref.watch(activePlaylistIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Listas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Exportar Backup',
            onPressed: () => BackupService.exportData(context),
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Restaurar Backup',
            onPressed: () async {
              final success = await BackupService.importData(context);
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup importado correctamente. Abre la app nuevamente.')),
                );
                ref.invalidate(localPlaylistsProvider);
              }
            },
          ),
        ],
      ),
      body: playlistsAsyncValue.when(
        data: (playlists) {
          if (playlists.isEmpty) {
            return const Center(child: Text('No playlists found. Add one!'));
          }
          return ListView.builder(
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              final isActive = activePlaylistId == playlist.id || (activePlaylistId == null && index == 0);
              
              return ListTile(
                leading: Icon(
                  isActive ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isActive ? Theme.of(context).primaryColor : Colors.grey,
                ),
                title: Text(playlist.name),
                subtitle: Text('${playlist.channels.length} channels'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (playlist.url.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        onPressed: () {
                          // Declaramos notifiers para el estado
                          final progressNotifier = ValueNotifier<(int, int, bool, int)>((0, 0, false, 0));

                          // Guardar el contexto del widget padre para usar en SnackBar si es necesario
                          final parentContext = context;

                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogContext) {
                              return ValueListenableBuilder<(int, int, bool, int)>(
                                valueListenable: progressNotifier,
                                builder: (context, value, child) {
                                  final receivedBytes = value.$1;
                                  final totalBytes = value.$2;
                                  final isProcessing = value.$3;
                                  final parsedChannels = value.$4;

                                  return AlertDialog(
                                    backgroundColor: const Color(0xFF1A1A24),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const CircularProgressIndicator(color: Colors.blue),
                                        const SizedBox(height: 16),
                                        if (isProcessing) ...[
                                          Text(
                                            parsedChannels > 0 
                                              ? 'Procesando canales... $parsedChannels\nPor favor espera'
                                              : 'Procesando canales... Por favor espera',
                                            style: const TextStyle(color: Colors.white),
                                            textAlign: TextAlign.center,
                                          ),
                                        ] else if (totalBytes > 0) ...[
                                          Text(
                                            'Descargando... ${((receivedBytes / totalBytes) * 100).toStringAsFixed(0)}%',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                          Text(
                                            '${(receivedBytes / 1024 / 1024).toStringAsFixed(1)} MB / ${(totalBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                                          ),
                                        ] else ...[
                                          Text(
                                            'Descargando... ${(receivedBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ]
                                      ],
                                    ),
                                  );
                                }
                              );
                            },
                          );

                          // Llamamos al proceso de forma asíncrona pero actualizamos el dialogContext
                          Future.microtask(() async {
                            final result = await ref.read(playlistRepositoryProvider).fetchPlaylist(
                              playlist.name, 
                              playlist.url,
                              onReceiveProgress: (count, total) {
                                progressNotifier.value = (count, total, false, 0);
                              },
                              onProcessingStarted: () {
                                progressNotifier.value = (progressNotifier.value.$1, progressNotifier.value.$2, true, 0);
                              },
                              onChannelsParsed: (count) {
                                progressNotifier.value = (progressNotifier.value.$1, progressNotifier.value.$2, true, count);
                              },
                            );
                            
                            // Cuando termine, cerramos el diálogo y mostramos mensaje
                            if (parentContext.mounted) {
                              Navigator.of(parentContext, rootNavigator: true).pop();
                              
                              result.fold(
                                (failure) => ScaffoldMessenger.of(parentContext).showSnackBar(
                                  SnackBar(content: Text('Error: ${failure.message}')),
                                ),
                                (newPlaylist) async {
                                  // Update active playlist if necessary
                                  final activeId = ref.read(activePlaylistIdProvider);
                                  if (activeId == playlist.id) {
                                    ref.read(activePlaylistIdProvider.notifier).setActivePlaylist(newPlaylist.id);
                                  }
                                  
                                  // Elimina la versión antigua para que no se duplique
                                  await ref.read(playlistRepositoryProvider).deletePlaylist(playlist.id);
                                  
                                  if (parentContext.mounted) {
                                    ScaffoldMessenger.of(parentContext).showSnackBar(
                                      SnackBar(content: Text('${playlist.name} actualizada con éxito!')),
                                    );
                                  }
                                },
                              );
                              ref.invalidate(localPlaylistsProvider);
                            }
                            progressNotifier.dispose();
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        await ref.read(playlistRepositoryProvider).deletePlaylist(playlist.id);
                        ref.invalidate(localPlaylistsProvider);
                      },
                    ),
                  ],
                ),
                onTap: () async {
                  // Mostrar indicador de carga para listas pesadas
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      backgroundColor: Color(0xFF1A1A24),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.blue),
                          SizedBox(height: 16),
                          Text('Cambiando lista...', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  );

                  // Pequeña pausa para permitir que el diálogo se renderice
                  await Future.delayed(const Duration(milliseconds: 100));

                  // Cambiar la lista (esto dispara el recálculo pesado en MainDashboard)
                  ref.read(activePlaylistIdProvider.notifier).setActivePlaylist(playlist.id);

                  // Esperar a que los widgets pesados terminen de reconstruirse
                  await Future.delayed(const Duration(milliseconds: 800));

                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pop(); // Cerrar diálogo
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${playlist.name} establecida como activa')),
                    );
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddPlaylistDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
