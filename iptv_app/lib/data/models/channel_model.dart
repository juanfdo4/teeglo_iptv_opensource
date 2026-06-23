import '../../domain/entities/channel.dart';

class ChannelModel extends Channel {
  const ChannelModel({
    required super.id,
    required super.name,
    required super.url,
    required super.logoUrl,
    required super.group,
  });

  factory ChannelModel.fromJson(Map<String, dynamic> json) {
    return ChannelModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      url: json['url'] ?? '',
      logoUrl: json['logoUrl'] ?? '',
      group: json['group'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'logoUrl': logoUrl,
      'group': group,
    };
  }
}
