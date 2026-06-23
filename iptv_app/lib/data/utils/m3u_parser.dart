import '../models/channel_model.dart';

class M3uParser {
  static List<ChannelModel> parse(String content) {
    if (!content.trim().startsWith('#EXTM3U')) {
      return [];
    }

    final lines = content.split(RegExp(r'\r?\n'));
    final List<ChannelModel> channels = [];

    String? currentName;
    String? currentLogoUrl;
    String? currentGroup;
    String? currentId;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF:')) {
        currentName = _extractName(line);
        currentLogoUrl = _extractAttribute(line, 'tvg-logo');
        currentGroup = _extractAttribute(line, 'group-title');
        
        // Extraer xui-id primero, luego tvg-id
        currentId = _extractAttribute(line, 'xui-id');
        if (currentId == null || currentId.trim().isEmpty) {
          currentId = _extractAttribute(line, 'tvg-id');
        }
        if (currentId != null && currentId.trim().isEmpty) {
          currentId = null;
        }
      } else if (!line.startsWith('#')) {
        // This is likely the URL
        if (currentName != null) {
          final uniqueId = currentId != null ? '${currentId}_${line.trim()}' : line.trim();
          channels.add(ChannelModel(
            id: uniqueId, // Guarantee uniqueness by including the URL
            name: currentName,
            url: line,
            logoUrl: currentLogoUrl ?? '',
            group: currentGroup ?? 'Uncategorized',
          ));
          
          // Reset for the next channel
          currentName = null;
          currentLogoUrl = null;
          currentGroup = null;
          currentId = null;
        }
      }
    }

    return channels;
  }

  static String _extractName(String line) {
    final split = line.split(',');
    if (split.length > 1) {
      return split.last.trim();
    }
    return 'Unknown Channel';
  }

  static String? _extractAttribute(String line, String attribute) {
    final regex = RegExp('$attribute="([^"]*)"');
    final match = regex.firstMatch(line);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }
}
