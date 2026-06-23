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
