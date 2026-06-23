import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/channel.dart';
import '../../player/pages/video_player_screen.dart';
import '../providers/favorites_provider.dart';
import '../../player/providers/playback_progress_provider.dart';

class ChannelListWidget extends ConsumerStatefulWidget {
  final List<Channel> channels;

  const ChannelListWidget({super.key, required this.channels});

  @override
  ConsumerState<ChannelListWidget> createState() => _ChannelListWidgetState();
}

class _ChannelListWidgetState extends ConsumerState<ChannelListWidget> {
  String _selectedCategory = 'All';
  late List<String> _categories;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _extractCategories();
  }

  @override
  void didUpdateWidget(covariant ChannelListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channels != widget.channels) {
      _extractCategories();
      _selectedCategory = 'All';
      _searchQuery = '';
    }
  }

  void _extractCategories() {
    final categoriesSet = widget.channels.map((c) => c.group).toSet();
    _categories = ['All', ...categoriesSet.toList()..sort()];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) {
      return const Center(child: Text('No content available.')).animate().fadeIn(duration: 400.ms);
    }

    // Filter by Category
    var filteredChannels = _selectedCategory == 'All'
        ? widget.channels
        : widget.channels.where((c) => c.group == _selectedCategory).toList();

    // Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filteredChannels = filteredChannels.where((c) => c.name.toLowerCase().contains(q)).toList();
    }

    ref.watch(playbackProgressProvider); // Rebuilds when state (int) changes
    final progressService = ref.read(playbackProgressProvider.notifier);

    // Siempre ordenar alfabéticamente pero dando prioridad al progreso
    filteredChannels.sort((a, b) {
      final aWatched = progressService.isWatched(a.url);
      final bWatched = progressService.isWatched(b.url);
      final aProg = progressService.getProgress(a.url);
      final bProg = progressService.getProgress(b.url);
      
      int getWeight(bool watched, Duration? prog) {
        if (watched) return 3; // Fully watched goes to bottom
        if (prog != null && prog.inSeconds > 0) return 1; // In progress goes to top
        return 2; // Unwatched in middle
      }
      
      final weightA = getWeight(aWatched, aProg);
      final weightB = getWeight(bWatched, bProg);
      
      if (weightA != weightB) {
        return weightA.compareTo(weightB);
      }
      
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar canales...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
        ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0),
        // Categories Horizontal List
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(category.isEmpty ? 'Uncategorized' : category),
                  selected: isSelected,
                  selectedColor: Colors.blue.withValues(alpha: 0.3),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    }
                  },
                ),
              ).animate(delay: (index * 50).ms).fadeIn(duration: 300.ms).slideX(begin: 0.2, end: 0);
            },
          ),
        ),
        const Divider(height: 1),
        // Channels List
        Expanded(
          child: filteredChannels.isEmpty
              ? const Center(child: Text('No matches found.')).animate().fadeIn()
              : ListView.builder(
                  // Use a key to force re-animation when category changes
                  key: ValueKey(_selectedCategory + _searchQuery),
                  itemCount: filteredChannels.length,
                  itemBuilder: (context, index) {
                    final channel = filteredChannels[index];
                    return ListTile(
                      leading: Hero(
                        tag: 'logo_${channel.id}',
                        child: channel.logoUrl.isNotEmpty
                            ? Image.network(
                                channel.logoUrl,
                                width: 50,
                                height: 50,
                                errorBuilder: (ctx, err, stack) => const Icon(Icons.tv),
                              )
                            : const Icon(Icons.tv),
                      ),
                      title: Text(channel.name),
                      subtitle: Text(
                        channel.group,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: Consumer(
                        builder: (context, ref, child) {
                          final isFav = ref.watch(favoritesProvider).any((c) => c.id == channel.id);
                          return IconButton(
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              ref.read(favoritesProvider.notifier).toggleFavorite(channel);
                            },
                          );
                        },
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(channel: channel),
                          ),
                        );
                      },
                    ).animate(delay: (index.clamp(0, 20) * 30).ms).fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
                  },
                ),
        ),
      ],
    );
  }
}
