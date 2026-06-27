import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/channel.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/category_selector_widget.dart';
import 'series_detail_page.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../player/providers/playback_progress_provider.dart';

class _SeriesDataResult {
  final Map<String, List<Channel>> groupedSeries;
  final List<Channel> uniqueSeriesList;
  final List<String> categories;

  _SeriesDataResult(this.groupedSeries, this.uniqueSeriesList, this.categories);
}

_SeriesDataResult _groupSeriesWorker(List<Channel> episodes) {
  final groupedSeries = <String, List<Channel>>{};
  for (final ep in episodes) {
    final key = ep.seriesName ?? ep.name;
    final list = groupedSeries.putIfAbsent(key, () => []);
    
    // Evitar episodios duplicados que vienen de diferentes categorías del proveedor
    final isDuplicate = list.any((existing) {
      if (ep.season != null && ep.episode != null && existing.season != null && existing.episode != null) {
        return existing.season == ep.season && existing.episode == ep.episode;
      }
      return existing.name.trim().toLowerCase() == ep.name.trim().toLowerCase();
    });
    
    if (!isDuplicate) {
      list.add(ep);
    }
  }

  final uniqueSeriesList = groupedSeries.values.map((eps) {
    eps.sort((a, b) {
      final sComp = (a.season ?? 0).compareTo(b.season ?? 0);
      if (sComp != 0) return sComp;
      return (a.episode ?? 0).compareTo(b.episode ?? 0);
    });
    return eps.first;
  }).toList();

  final categories = ['Todos', ...uniqueSeriesList.map((c) => c.group).toSet().toList()..sort()];

  return _SeriesDataResult(groupedSeries, uniqueSeriesList, categories);
}

class SeriesPage extends ConsumerStatefulWidget {
  final List<Channel> seriesEpisodes;

  const SeriesPage({super.key, required this.seriesEpisodes});

  @override
  ConsumerState<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends ConsumerState<SeriesPage> {
  String _searchQuery = '';
  String _selectedCategory = 'Todos';

  bool _isLoading = true;
  late Map<String, List<Channel>> _groupedSeries;
  late List<Channel> _uniqueSeriesList;
  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    _processData();
  }

  @override
  void didUpdateWidget(SeriesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.seriesEpisodes != oldWidget.seriesEpisodes) {
      setState(() {
        _isLoading = true;
        // Reset category to 'Todos' if the list changed, to avoid being stuck in a category that doesn't exist
        _selectedCategory = 'Todos'; 
      });
      _processData();
    }
  }

  Future<void> _processData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final result = await compute(_groupSeriesWorker, widget.seriesEpisodes);
    if (mounted) {
      setState(() {
        _groupedSeries = result.groupedSeries;
        _uniqueSeriesList = result.uniqueSeriesList;
        _categories = result.categories;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.teegloCyan));
    }

    final filteredSeries = _uniqueSeriesList.where((series) {
      final seriesName = series.seriesName ?? series.name;
      final matchesSearch = seriesName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Todos' || series.group == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    ref.watch(playbackProgressProvider); // Rebuilds when state changes
    final progressService = ref.read(playbackProgressProvider.notifier);

    // Cache weights to avoid hitting the local DB inside the sort loop
    final weights = <String, int>{};
    final progresses = <String, double>{};
    
    for (final series in filteredSeries) {
      final seriesName = series.seriesName ?? series.name;
      final allEpisodes = _groupedSeries[seriesName]!;
      final prog = progressService.getSeriesProgress(allEpisodes);
      
      progresses[seriesName] = prog['progressPercent'] as double;
      if (prog['isWatched']) {
        weights[seriesName] = 3; // Watched at bottom
      } else if ((prog['progressPercent'] as double) > 0) {
        weights[seriesName] = 1; // In progress at top
      } else {
        weights[seriesName] = 2; // Unwatched in middle
      }
    }

    // Sort: In Progress > Unwatched > Watched
    filteredSeries.sort((a, b) {
      final aName = a.seriesName ?? a.name;
      final bName = b.seriesName ?? b.name;
      
      final wA = weights[aName] ?? 2;
      final wB = weights[bName] ?? 2;
      
      if (wA != wB) return wA.compareTo(wB);
      
      if (wA == 1) {
        return (progresses[bName] ?? 0).compareTo(progresses[aName] ?? 0);
      }
      
      return aName.compareTo(bName);
    });

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar series...',
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
          child: filteredSeries.isEmpty
              ? const Center(child: Text('No se encontraron series'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredSeries.length,
                  itemBuilder: (context, index) {
                    final seriesRep = filteredSeries[index];
                    final seriesName = seriesRep.seriesName ?? seriesRep.name;
                    final allEpisodes = _groupedSeries[seriesName]!;
                    final isWatched = weights[seriesName] == 3;
                    final progressPercent = progresses[seriesName] ?? 0.0;

                    return GestureDetector(
                      onLongPress: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: AppTheme.bgSurface,
                          builder: (context) {
                            return SafeArea(
                              child: Wrap(
                                children: [
                                  ListTile(
                                    leading: Icon(isWatched ? Icons.remove_circle_outline : Icons.check_circle_outline, color: Colors.white),
                                    title: Text(isWatched ? 'Marcar como no visto' : 'Marcar como visto', style: const TextStyle(color: Colors.white)),
                                    onTap: () {
                                      Navigator.pop(context);
                                      if (isWatched) {
                                        ref.read(playbackProgressProvider.notifier).markSeriesAsUnwatched(allEpisodes);
                                      } else {
                                        ref.read(playbackProgressProvider.notifier).markSeriesAsWatched(allEpisodes);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SeriesDetailPage(
                              seriesName: seriesName,
                              episodes: allEpisodes,
                              representativeChannel: seriesRep,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: AppTheme.bgSurface,
                          image: seriesRep.logoUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(seriesRep.logoUrl),
                                  fit: BoxFit.cover,
                                  onError: (exception, stackTrace) => const Icon(Icons.tv),
                                )
                              : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            if (seriesRep.logoUrl.isEmpty)
                              const Center(child: Icon(Icons.tv, color: Colors.white54, size: 40)),
                            
                            // Watched indicator
                            if (isWatched)
                              Positioned(
                                top: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, color: Colors.greenAccent, size: 14),
                                ),
                              ),
                            
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 60,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.8),
                                      Colors.black,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            Positioned(
                              bottom: 8,
                              left: 8,
                              right: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${allEpisodes.length} Episodios',
                                    style: const TextStyle(color: AppTheme.teegloCyan, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    seriesName,
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Progress bar at the very bottom
                            if (!isWatched && progressPercent > 0)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: LinearProgressIndicator(
                                  value: progressPercent,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                                  minHeight: 4,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
