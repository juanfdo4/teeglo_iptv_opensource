import '../../domain/entities/channel.dart';

class ChannelModel extends Channel {
  const ChannelModel({
    required super.id,
    required super.name,
    required super.url,
    required super.logoUrl,
    required super.group,
    super.contentType,
    super.seriesName,
    super.season,
    super.episode,
    super.year,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      logoUrl: json['logoUrl'] ?? '',
      group: json['group'] ?? '',
      contentType: ContentType.values.firstWhere(
        (e) => e.name == (json['contentType'] ?? 'live'),
        orElse: () => ContentType.live,
      ),
      seriesName: json['seriesName'],
      season: json['season'],
      episode: json['episode'],
      year: json['year'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'logoUrl': logoUrl,
      'group': group,
      'contentType': contentType.name,
      'seriesName': seriesName,
      'season': season,
      'episode': episode,
      'year': year,
    };
  }
}
