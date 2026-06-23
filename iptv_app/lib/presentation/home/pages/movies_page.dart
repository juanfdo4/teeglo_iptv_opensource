import 'package:flutter/material.dart';
import '../../../domain/entities/channel.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/content_card.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../player/providers/playback_progress_provider.dart';

class MoviesPage extends ConsumerStatefulWidget {
  final List<Channel> movies;

  const MoviesPage({super.key, required this.movies});

  @override
  ConsumerState<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends ConsumerState<MoviesPage> {
  String _searchQuery = '';
  String _selectedCategory = 'Todos';

  @override
  Widget build(BuildContext context) {
    final categories = ['Todos', ...widget.movies.map((c) => c.group).toSet().toList()..sort()];

    final filteredMovies = widget.movies.where((movie) {
      final matchesSearch = movie.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Todos' || movie.group == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    ref.watch(playbackProgressProvider); // Rebuilds when state (int) changes
    final progressService = ref.read(playbackProgressProvider.notifier);

    filteredMovies.sort((a, b) {
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
      
      return a.name.compareTo(b.name);
    });

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar películas...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
              filled: true,
              fillColor: AppTheme.bgSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),

        // Category Chips
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = category);
                  },
                  selectedColor: AppTheme.teegloCyan.withOpacity(0.2),
                  backgroundColor: AppTheme.bgSurface,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.teegloCyan : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppTheme.teegloCyan : Colors.transparent,
                  ),
                ),
              );
            },
          ),
        ),

        // Grid
        Expanded(
          child: filteredMovies.isEmpty
              ? const Center(child: Text('No se encontraron películas'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 3 columns for posters
                    childAspectRatio: 0.7, // Taller for posters
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredMovies.length,
                  itemBuilder: (context, index) {
                    return ContentCard(channel: filteredMovies[index]);
                  },
                ),
        ),
      ],
    );
  }
}
