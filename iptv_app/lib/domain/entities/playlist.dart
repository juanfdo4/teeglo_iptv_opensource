import 'package:equatable/equatable.dart';
import 'channel.dart';

class Playlist extends Equatable {
  final String id;
  final String name;
  final String url;
  final List<Channel> channels;

  const Playlist({
    required this.id,
    required this.name,
    required this.url,
    required this.channels,
  });

  @override
  List<Object> get props => [id, name, url, channels];
}
