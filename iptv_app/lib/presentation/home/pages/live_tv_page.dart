import 'package:flutter/material.dart';
import '../../../domain/entities/channel.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/content_card.dart';
import '../widgets/category_selector_widget.dart';

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

        // Category Selector (New Dropdown-like UI)
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: CategorySelectorWidget(
            categories: categories,
            selectedCategory: _selectedCategory,
            onCategorySelected: (cat) => setState(() => _selectedCategory = cat),
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
