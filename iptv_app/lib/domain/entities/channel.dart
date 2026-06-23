import 'package:equatable/equatable.dart';

class Channel extends Equatable {
  final String id;
  final String name;
  final String url;
  final String logoUrl;
  final String group;

  const Channel({
    required this.id,
    required this.name,
    required this.url,
    required this.logoUrl,
    required this.group,
  });

  @override
  List<Object> get props => [id, name, url, logoUrl, group];
}
