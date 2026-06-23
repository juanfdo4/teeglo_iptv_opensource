import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../domain/entities/channel.dart';
import 'content_card.dart';

class ContentCarousel extends StatelessWidget {
  final String title;
  final List<Channel> channels;

  const ContentCarousel({
    super.key,
    required this.title,
    required this.channels,
  });

  @override
  Widget build(BuildContext context) {
    if (channels.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: channels.length,
            itemBuilder: (context, index) {
              return ContentCard(channel: channels[index])
                  .animate(delay: (index.clamp(0, 10) * 50).ms)
                  .fadeIn(duration: 400.ms)
                  .slideX(begin: 0.1, end: 0);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
