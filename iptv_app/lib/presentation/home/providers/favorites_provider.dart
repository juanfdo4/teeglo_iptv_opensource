import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../data/models/channel_model.dart';
import '../../../domain/entities/channel.dart';

final favoritesProvider = NotifierProvider<FavoritesNotifier, List<Channel>>(() {
  return FavoritesNotifier();
});

class FavoritesNotifier extends Notifier<List<Channel>> {
  @override
  List<Channel> build() {
    return _loadFavorites();
  }

  List<Channel> _loadFavorites() {
    final box = Hive.box('favorites');
    final List<Channel> favs = [];
    for (var key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        final jsonMap = Map<String, dynamic>.from(data as Map);
        favs.add(ChannelModel.fromJson(jsonMap));
      }
    }
    return favs;
  }

  bool isFavorite(String channelId) {
    return Hive.box('favorites').containsKey(channelId);
  }

  Future<void> toggleFavorite(Channel channel) async {
    final box = Hive.box('favorites');
    if (isFavorite(channel.id)) {
      await box.delete(channel.id);
    } else {
      final model = ChannelModel(
        id: channel.id,
        name: channel.name,
        url: channel.url,
        logoUrl: channel.logoUrl,
        group: channel.group,
      );
      await box.put(channel.id, model.toJson());
    }
    state = _loadFavorites();
  }
}
