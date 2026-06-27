import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/channel.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/content_card.dart';
import '../widgets/category_selector_widget.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../player/providers/playback_progress_provider.dart';

List<String> _extractCategoriesWorker(List<Channel> movies) {
  return ['Todos', ...movies.map((c) => c.group).toSet().toList()..sort()];
}

class MoviesPage extends ConsumerStatefulWidget {
  final List<Channel> movies;

  const MoviesPage({super.key, required this.movies});

  @override
  ConsumerState<MoviesPage> createState() => _MoviesPageState();
}

class _MoviesPageState extends ConsumerState<MoviesPage> {
  String _searchQuery = '';
  String _selectedCategory = 'Todos';

  bool _isLoading = true;
  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    _processData();
  }

  @override
  void didUpdateWidget(MoviesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.movies != oldWidget.movies) {
      setState(() {
        _isLoading = true;
        _selectedCategory = 'Todos';
      });
      _processData();
    }
  }

  Future<void> _processData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final cats = await compute(_extractCategoriesWorker, widget.movies);
    if (mounted) {
      setState(() {
        _categories = cats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.teegloCyan));
    }

    final filteredMovies = widget.movies.where((movie) {
      final matchesSearch = movie.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Todos' || movie.group == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    ref.watch(playbackProgressProvider); // Rebuilds when state (int) changes
    final progressService = ref.read(playbackProgressProvider.notifier);

    // Cache weights to avoid DB calls in sort
    final weights = <String, int>{};
    for (final m in filteredMovies) {
      final isWatched = progressService.isWatched(m.url);
      final prog = progressService.getProgress(m.url);
      if (isWatched) {
        weights[m.url] = 3;
      } else if (prog != null && prog.inSeconds > 0) {
        weights[m.url] = 1;
      } else {
        weights[m.url] = 2;
      }
    }

    filteredMovies.sort((a, b) {
      final wA = weights[a.url] ?? 2;
      final wB = weights[b.url] ?? 2;
      if (wA != wB) return wA.compareTo(wB);
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

        // Category Selector (New Dropdown-like UI)
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: CategorySelectorWidget(
            categories: _categories,
            selectedCategory: _selectedCategory,
            onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
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
