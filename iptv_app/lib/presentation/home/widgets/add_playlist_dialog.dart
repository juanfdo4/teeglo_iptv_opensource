import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import '../providers/home_provider.dart';

enum PlaylistInputType { file, url, xtream }

class AddPlaylistDialog extends ConsumerStatefulWidget {
  const AddPlaylistDialog({super.key});

  @override
  ConsumerState<AddPlaylistDialog> createState() => _AddPlaylistDialogState();
}

class _AddPlaylistDialogState extends ConsumerState<AddPlaylistDialog> {
  PlaylistInputType _inputType = PlaylistInputType.xtream; // Default to the new cool one

  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isProcessing = false;
  int _receivedBytes = 0;
  int _totalBytes = 0;

  Future<void> _addRemotePlaylist() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    
    if (name.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa nombre y URL')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isProcessing = false;
      _receivedBytes = 0;
      _totalBytes = 0;
    });
    
    final repo = ref.read(playlistRepositoryProvider);
    final result = await repo.fetchPlaylist(
      name, 
      url,
      onReceiveProgress: (count, total) {
        if (mounted) {
          setState(() {
            _receivedBytes = count;
            _totalBytes = total;
          });
        }
      },
      onProcessingStarted: () {
        if (mounted) setState(() => _isProcessing = true);
      },
    );
    
    setState(() => _isLoading = false);

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${failure.message}')),
      ),
      (playlist) {
        ref.invalidate(localPlaylistsProvider);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  Future<void> _addXtreamPlaylist() async {
    final name = _nameController.text.trim();
    final serverUrl = _serverUrlController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    
    if (name.isEmpty || serverUrl.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena todos los campos')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isProcessing = false;
      _receivedBytes = 0;
      _totalBytes = 0;
    });
    
    final cleanServerUrl = serverUrl.endsWith('/') ? serverUrl.substring(0, serverUrl.length - 1) : serverUrl;
    final fullUrl = '$cleanServerUrl/get.php?username=$username&password=$password&type=m3u_plus&output=mpegts';
    
    final repo = ref.read(playlistRepositoryProvider);
    final result = await repo.fetchPlaylist(
      name, 
      fullUrl,
      onReceiveProgress: (count, total) {
        if (mounted) {
          setState(() {
            _receivedBytes = count;
            _totalBytes = total;
          });
        }
      },
      onProcessingStarted: () {
        if (mounted) setState(() => _isProcessing = true);
      },
    );
    
    setState(() => _isLoading = false);

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${failure.message}')),
      ),
      (playlist) {
        ref.invalidate(localPlaylistsProvider);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  Future<void> _addLocalPlaylist() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un nombre primero')),
      );
      return;
    }

    final XFile? file = await openFile();

    if (file != null) {
      setState(() {
        _isLoading = true;
        _isProcessing = true; // Local file processing
      });
      
      try {
        final content = await file.readAsString();
        
        final repo = ref.read(playlistRepositoryProvider);
        final repoResult = await repo.addPlaylistFromContent(
          name, 
          content,
          onProcessingStarted: () {
            if (mounted) setState(() => _isProcessing = true);
          },
        );
        
        repoResult.fold(
          (failure) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${failure.message}')),
          ),
          (playlist) {
            ref.invalidate(localPlaylistsProvider);
            if (mounted) Navigator.pop(context);
          },
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fallo al leer archivo: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar Lista IPTV'),
      backgroundColor: const Color(0xFF1A1A24),
      surfaceTintColor: Colors.transparent,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isLoading) ...[
              const SizedBox(height: 16),
              if (!_isProcessing && _totalBytes > 0) ...[
                Text(
                  'Descargando... ${(_receivedBytes / 1024 / 1024).toStringAsFixed(1)} MB / ${(_totalBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _receivedBytes / _totalBytes,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 8),
                Text(
                  '${((_receivedBytes / _totalBytes) * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ] else if (!_isProcessing && _totalBytes <= 0) ...[
                Text(
                  'Descargando... ${(_receivedBytes / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const LinearProgressIndicator(
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ] else ...[
                const Text(
                  'Procesando canales... Por favor espera',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator(color: Colors.blue)),
              ],
              const SizedBox(height: 16),
            ] else ...[
              SegmentedButton<PlaylistInputType>(
              segments: const [
                ButtonSegment(
                  value: PlaylistInputType.xtream,
                  label: Text('Xtream API', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: PlaylistInputType.url,
                  label: Text('URL', style: TextStyle(fontSize: 12)),
                ),
                ButtonSegment(
                  value: PlaylistInputType.file,
                  label: Text('Archivo', style: TextStyle(fontSize: 12)),
                ),
              ],
              selected: {_inputType},
              onSelectionChanged: (Set<PlaylistInputType> newSelection) {
                setState(() {
                  _inputType = newSelection.first;
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.blue.withValues(alpha: 0.3);
                  }
                  return Colors.transparent;
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.grey;
                }),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nombre de la lista (ej: Mi TV)',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
              ),
            ),
            const SizedBox(height: 16),

            if (_inputType == PlaylistInputType.url) ...[
              TextField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'URL Completa (.m3u)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                ),
              ),
            ],

            if (_inputType == PlaylistInputType.xtream) ...[
              TextField(
                controller: _serverUrlController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'URL Base (ej: http://red4tv.lat:80)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                ),
              ),
            ],

            if (_inputType == PlaylistInputType.file) ...[
              const SizedBox(height: 16),
              const Text(
                'Selecciona el botón de abajo para buscar tu archivo .m3u local',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ]
          ] // closes else
        ], // closes children
      ),
      ),
      actions: [
        if (_isLoading)
          const SizedBox.shrink(),
        if (!_isLoading) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          
          if (_inputType == PlaylistInputType.file)
            ElevatedButton(
              onPressed: _addLocalPlaylist,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Buscar Archivo', style: TextStyle(color: Colors.white)),
            )
          else if (_inputType == PlaylistInputType.url)
            ElevatedButton(
              onPressed: _addRemotePlaylist,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Agregar URL', style: TextStyle(color: Colors.white)),
            )
          else if (_inputType == PlaylistInputType.xtream)
            ElevatedButton(
              onPressed: _addXtreamPlaylist,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('Conectar', style: TextStyle(color: Colors.white)),
            )
        ]
      ],
    );
  }
}
