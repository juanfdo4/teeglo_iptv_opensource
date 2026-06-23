import 'package:flutter/material.dart';
import '../../../domain/entities/channel.dart';
import '../../../core/theme/app_theme.dart';
import 'series_detail_page.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../player/providers/playback_progress_provider.dart';

class SeriesPage extends ConsumerStatefulWidget {
  final List<Channel> seriesEpisodes;

  const SeriesPage({super.key, required this.seriesEpisodes});

  @override
  ConsumerState<SeriesPage> createState() => _SeriesPageState();
}

class _SeriesPageState extends ConsumerState<SeriesPage> {
  String _searchQuery = '';
  String _selectedCategory = 'Todos';

  @override
  Widget build(BuildContext context) {
    // Group episodes by seriesName
    final groupedSeries = <String, List<Channel>>{};
    for (final ep in widget.seriesEpisodes) {
      final key = ep.seriesName ?? ep.name;
      groupedSeries.putIfAbsent(key, () => []).add(ep);
    }

    // Convert to a list of "Series" objects (using the first episode for metadata)
    final uniqueSeriesList = groupedSeries.values.map((episodes) {
      // Sort episodes by season and then episode
      episodes.sort((a, b) {
        final sComp = (a.season ?? 0).compareTo(b.season ?? 0);
        if (sComp != 0) return sComp;
        return (a.episode ?? 0).compareTo(b.episode ?? 0);
      });
      return episodes.first; // Representative episode for the series card
    }).toList();

    // Extract categories based on the representative episode
    final categories = ['Todos', ...uniqueSeriesList.map((c) => c.group).toSet().toList()..sort()];

    final filteredSeries = uniqueSeriesList.where((series) {
      final seriesName = series.seriesName ?? series.name;
      final matchesSearch = seriesName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Todos' || series.group == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    ref.watch(playbackProgressProvider); // Rebuilds when state (int) changes
    final progressService = ref.read(playbackProgressProvider.notifier);

    // Sort: In Progress > Unwatched > Watched
    filteredSeries.sort((a, b) {
      final aName = a.seriesName ?? a.name;
      final bName = b.seriesName ?? b.name;
      
      final aProgress = progressService.getSeriesProgress(groupedSeries[aName]!);
      final bProgress = progressService.getSeriesProgress(groupedSeries[bName]!);
      
      int getWeight(Map<String, dynamic> prog) {
        if (prog['isWatched']) return 3; // Fully watched goes to bottom
        if (prog['progressPercent'] > 0) return 1; // In progress goes to top
        return 2; // Unwatched in middle
      }
      
      final weightA = getWeight(aProgress);
      final weightB = getWeight(bProgress);
      
      if (weightA != weightB) {
        return weightA.compareTo(weightB);
      }
      
      // Secondary sort: if both in progress, sort by higher progress first?
      if (weightA == 1 && weightB == 1) {
        return (bProgress['progressPercent'] as double).compareTo(aProgress['progressPercent'] as double);
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
                    final allEpisodes = groupedSeries[seriesName]!;
                    final seriesProgressInfo = progressService.getSeriesProgress(allEpisodes);
                    final isWatched = seriesProgressInfo['isWatched'];
                    final progressPercent = seriesProgressInfo['progressPercent'] as double;

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
                                    color: Colors.black.withOpacity(0.7),
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
                                      Colors.black.withOpacity(0.8),
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
