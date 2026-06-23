import 'package:equatable/equatable.dart';

enum ContentType { live, movie, series }

class Channel extends Equatable {
  final String id;
  final String name;
  final String url;
  final String logoUrl;
  final String group;
  final ContentType contentType;
  final String? seriesName;
  final int? season;
  final int? episode;
  final String? year;

  const Channel({
    required this.id,
    required this.name,
    required this.url,
    required this.logoUrl,
    required this.group,
    this.contentType = ContentType.live,
    this.seriesName,
    this.season,
    this.episode,
    this.year,
  });

  @override
  List<Object?> get props => [id, name, url, logoUrl, group, contentType, seriesName, season, episode, year];
}
