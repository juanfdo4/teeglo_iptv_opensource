import 'package:flutter/material.dart';
import '../../../domain/entities/channel.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/content_card.dart';

class LiveTvPage extends StatefulWidget {
  final List<Channel> channels;

  const LiveTvPage({super.key, required this.channels});

  @override
  State<LiveTvPage> createState() => _LiveTvPageState();
}

class _LiveTvPageState extends State<LiveTvPage> {
  String _searchQuery = '';
  String _selectedCategory = 'Todos';

  @override
  Widget build(BuildContext context) {
    // Extract unique categories
    final categories = ['Todos', ...widget.channels.map((c) => c.group).toSet().toList()..sort()];

    // Filter channels
    final filteredChannels = widget.channels.where((channel) {
      final matchesSearch = channel.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'Todos' || channel.group == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Buscar canales en vivo...',
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
          child: filteredChannels.isEmpty
              ? const Center(child: Text('No se encontraron canales'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredChannels.length,
                  itemBuilder: (context, index) {
                    return ContentCard(channel: filteredChannels[index]);
                  },
                ),
        ),
      ],
    );
  }
}
