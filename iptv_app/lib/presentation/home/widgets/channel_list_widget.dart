import 'package:flutter/material.dart';
import '../../../domain/entities/channel.dart';
import '../../player/pages/video_player_screen.dart';

class ChannelListWidget extends StatefulWidget {
  final List<Channel> channels;

  const ChannelListWidget({super.key, required this.channels});

  @override
  State<ChannelListWidget> createState() => _ChannelListWidgetState();
}

class _ChannelListWidgetState extends State<ChannelListWidget> {
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
      return const Center(child: Text('No content available.'));
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

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search channels...',
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
        ),
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
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    }
                  },
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        // Channels List
        Expanded(
          child: filteredChannels.isEmpty
              ? const Center(child: Text('No matches found.'))
              : ListView.builder(
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
