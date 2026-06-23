import 'package:flutter/material.dart';
import '../../../domain/entities/channel.dart';
import '../../../core/theme/app_theme.dart';
import '../../player/pages/video_player_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../player/providers/playback_progress_provider.dart';

class SeriesDetailPage extends StatefulWidget {
  final String seriesName;
  final List<Channel> episodes;
  final Channel representativeChannel;

  const SeriesDetailPage({
    super.key,
    required this.seriesName,
    required this.episodes,
    required this.representativeChannel,
  });

  @override
  State<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends State<SeriesDetailPage> {
  int _selectedSeason = 1;

  @override
  void initState() {
    super.initState();
    // Sort all episodes globally once
    widget.episodes.sort((a, b) {
      int sComp = (a.season ?? 0).compareTo(b.season ?? 0);
      if (sComp != 0) return sComp;
      return (a.episode ?? 0).compareTo(b.episode ?? 0);
    });

    // Default to the first available season
    final seasons = widget.episodes.map((e) => e.season ?? 1).toSet().toList()..sort();
    if (seasons.isNotEmpty) {
      _selectedSeason = seasons.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final seasons = widget.episodes.map((e) => e.season ?? 1).toSet().toList()..sort();
    
    final currentSeasonEpisodes = widget.episodes
        .where((e) => (e.season ?? 1) == _selectedSeason)
        .toList()
      ..sort((a, b) => (a.episode ?? 0).compareTo(b.episode ?? 0));

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: CustomScrollView(
        slivers: [
          // Hero Banner Header
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.seriesName, style: const TextStyle(fontWeight: FontWeight.bold)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.representativeChannel.logoUrl.isNotEmpty)
                    Image.network(
                      widget.representativeChannel.logoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.tv, size: 100),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.bgDark.withOpacity(0.8),
                          AppTheme.bgDark,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Season Selector
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<int>(
                    value: _selectedSeason,
                    dropdownColor: AppTheme.bgSurface,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    items: seasons.map((season) {
                      return DropdownMenuItem<int>(
                        value: season,
                        child: Text('Temporada $season'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedSeason = value;
                        });
                      }
                    },
                  ),
                ),
              ),
            ),
          ),

          // Episodes List
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final episode = currentSeasonEpisodes[index];
                final globalIndex = widget.episodes.indexOf(episode);
                final nextEpisode = globalIndex >= 0 && globalIndex < widget.episodes.length - 1 
                    ? widget.episodes[globalIndex + 1] 
                    : null;

                    return Consumer(
                  builder: (context, ref, child) {
                    ref.watch(playbackProgressProvider); // Rebuilds when state (int) changes
                    final progressService = ref.read(playbackProgressProvider.notifier);
                    final isWatched = progressService.isWatched(episode.url);
                    final progress = progressService.getProgress(episode.url);
                    final duration = progressService.getDuration(episode.url);
                    
                    double progressPercent = 0.0;
                    if (progress != null && duration != null && duration.inSeconds > 0) {
                      progressPercent = progress.inSeconds / duration.inSeconds;
                    }
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 100,
                        height: 60,
                        decoration: BoxDecoration(
                          color: AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(4),
                          image: episode.logoUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(episode.logoUrl),
                                  fit: BoxFit.cover,
                                  onError: (e, s) => const Icon(Icons.tv),
                                )
                              : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Center(
                              child: isWatched 
                                  ? Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.check, color: Colors.greenAccent, size: 24),
                                    )
                                  : const Icon(Icons.play_circle_outline, color: Colors.white, size: 30),
                            ),
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
                      title: Text(
                        episode.name,
                        style: TextStyle(
                          color: isWatched ? Colors.white54 : Colors.white, 
                          fontWeight: FontWeight.w600
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Episodio ${episode.episode}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerScreen(
                              channel: episode,
                              nextEpisode: nextEpisode,
                            ),
                          ),
                        );
                      },
                    );
                  }
                );
              },
              childCount: currentSeasonEpisodes.length,
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }
}
