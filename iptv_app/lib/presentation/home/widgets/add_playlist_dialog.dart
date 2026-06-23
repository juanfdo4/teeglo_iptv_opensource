import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import '../providers/home_provider.dart';

class AddPlaylistDialog extends ConsumerStatefulWidget {
  const AddPlaylistDialog({super.key});

  @override
  ConsumerState<AddPlaylistDialog> createState() => _AddPlaylistDialogState();
}

class _AddPlaylistDialogState extends ConsumerState<AddPlaylistDialog> {
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  bool _isLoading = false;

  Future<void> _addRemotePlaylist() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    
    if (name.isEmpty || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name and URL')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    final repo = ref.read(playlistRepositoryProvider);
    final result = await repo.fetchPlaylist(name, url);
    
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
        const SnackBar(content: Text('Please enter a name first')),
      );
      return;
    }

    final XFile? file = await openFile();

    if (file != null) {
      setState(() => _isLoading = true);
      
      try {
        final content = await file.readAsString();
        
        final repo = ref.read(playlistRepositoryProvider);
        final repoResult = await repo.addPlaylistFromContent(name, content);
        
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
            SnackBar(content: Text('Failed to read file: $e')),
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
      title: const Text('Add Playlist'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Playlist Name'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(labelText: 'Playlist URL (Remote)'),
          ),
        ],
      ),
      actions: [
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircularProgressIndicator(),
          ),
        if (!_isLoading) ...[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _addLocalPlaylist,
            child: const Text('Local File'),
          ),
          TextButton(
            onPressed: _addRemotePlaylist,
            child: const Text('URL'),
          ),
        ]
      ],
    );
  }
}
