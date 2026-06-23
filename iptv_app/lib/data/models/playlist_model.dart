import '../../domain/entities/playlist.dart';
import 'channel_model.dart';

class PlaylistModel extends Playlist {
  const PlaylistModel({
    required super.id,
    required super.name,
    required super.url,
    required super.channels,
  });

  factory PlaylistModel.fromJson(Map<String, dynamic> json) {
    return PlaylistModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      channels: (json['channels'] as List<dynamic>?)
              ?.map((e) => ChannelModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'channels': channels.map((c) => (c as ChannelModel).toJson()).toList(),
    };
  }
}
