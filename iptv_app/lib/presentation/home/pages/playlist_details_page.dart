import 'package:flutter/material.dart';
import '../../../domain/entities/channel.dart';
import '../../../domain/entities/playlist.dart';
import '../../player/pages/video_player_screen.dart';

class PlaylistDetailsPage extends StatefulWidget {
  final Playlist playlist;

  const PlaylistDetailsPage({super.key, required this.playlist});

  @override
  State<PlaylistDetailsPage> createState() => _PlaylistDetailsPageState();
}

class _PlaylistDetailsPageState extends State<PlaylistDetailsPage> {
  late List<Channel> _liveChannels;
  late List<Channel> _vodChannels;

  @override
  void initState() {
    super.initState();
    _categorizeChannels();
  }

  void _categorizeChannels() {
    _liveChannels = [];
    _vodChannels = [];

    // Common keywords found in VOD categories
    final vodKeywords = ['movie', 'pelicula', 'película', 'serie', 'vod', 'cinema', '24/7', 'ppv'];

    for (final channel in widget.playlist.channels) {
      final groupLower = channel.group.toLowerCase();
      bool isVod = false;
      for (final keyword in vodKeywords) {
        if (groupLower.contains(keyword)) {
          isVod = true;
          break;
        }
      }

      if (isVod) {
        _vodChannels.add(channel);
      } else {
        _liveChannels.add(channel);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.playlist.name),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.live_tv), text: 'Live TV'),
              Tab(icon: Icon(Icons.movie), text: 'VOD / Series'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ChannelSection(channels: _liveChannels),
            _ChannelSection(channels: _vodChannels),
          ],
        ),
      ),
    );
  }
}

class _ChannelSection extends StatefulWidget {
  final List<Channel> channels;

  const _ChannelSection({required this.channels});

  @override
  State<_ChannelSection> createState() => _ChannelSectionState();
}

class _ChannelSectionState extends State<_ChannelSection> {
  String _selectedCategory = 'All';
  late List<String> _categories;

  @override
  void initState() {
    super.initState();
    _extractCategories();
  }

  @override
  void didUpdateWidget(covariant _ChannelSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channels != widget.channels) {
      _extractCategories();
      _selectedCategory = 'All';
    }
  }

  void _extractCategories() {
    final categoriesSet = widget.channels.map((c) => c.group).toSet();
    _categories = ['All', ...categoriesSet.toList()..sort()];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) {
      return const Center(child: Text('No content in this section.'));
    }

    final filteredChannels = _selectedCategory == 'All'
        ? widget.channels
        : widget.channels.where((c) => c.group == _selectedCategory).toList();

    return Row(
      children: [
        // Sidebar for categories
        SizedBox(
          width: 140,
          child: Container(
            color: Theme.of(context).cardColor,
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return ListTile(
                  title: Text(
                    category.isEmpty ? 'Uncategorized' : category,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).primaryColor : null,
                    ),
                  ),
                  selected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                );
              },
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        // Channels List
        Expanded(
          child: ListView.builder(
            itemCount: filteredChannels.length,
            itemBuilder: (context, index) {
              final channel = filteredChannels[index];
              return ListTile(
                leading: channel.logoUrl.isNotEmpty
                    ? Image.network(
                        channel.logoUrl,
                        width: 50,
                        height: 50,
                        errorBuilder: (ctx, err, stack) => const Icon(Icons.tv),
                      )
                    : const Icon(Icons.tv),
                title: Text(channel.name),
                subtitle: Text(
                  channel.group,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerScreen(channel: channel),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
