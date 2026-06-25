
import 'dart:isolate';
import '../models/channel_model.dart';
import '../../domain/entities/channel.dart';

class ParseRequest {
  final String content;
  final SendPort? progressPort;
  ParseRequest(this.content, this.progressPort);
}

class M3uParser {
  static List<ChannelModel> parseWithProgress(ParseRequest request) {
    return _parseInternal(request.content, request.progressPort);
  }

  static List<ChannelModel> parse(String content) {
    return _parseInternal(content, null);
  }

  static List<ChannelModel> _parseInternal(String content, SendPort? progressPort) {
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
          final year = _extractYear(currentName);
          final contentType = _detectContentType(line, currentName);
          String? seriesName;
          int? season;
          int? episode;

          if (contentType == ContentType.series) {
            final seriesInfo = _parseSeriesInfo(currentName);
            if (seriesInfo != null) {
              seriesName = seriesInfo.name;
              season = seriesInfo.season;
              episode = seriesInfo.episode;
            } else {
              // Si falla el parseo, fallback a pelicula
              seriesName = currentName;
            }
          }

          channels.add(ChannelModel(
            id: uniqueId, // Guarantee uniqueness by including the URL
            name: currentName,
            url: line,
            logoUrl: currentLogoUrl ?? '',
            group: currentGroup ?? 'Uncategorized',
            contentType: contentType,
            seriesName: seriesName,
            season: season,
            episode: episode,
            year: year,
          ));
          
          
          // Reset for the next channel
          currentName = null;
          currentLogoUrl = null;
          currentGroup = null;
          currentId = null;

          if (progressPort != null && channels.length % 500 == 0) {
            progressPort.send(channels.length);
          }
        }
      }
    }

    if (progressPort != null) {
      progressPort.send(channels.length);
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

  static ContentType _detectContentType(String url, String name) {
    final urlLower = url.toLowerCase();
    final fileExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.ts', '.flv'];
    final hasFileExt = fileExtensions.any((ext) => urlLower.contains('#$ext') || urlLower.endsWith(ext));
    
    if (!hasFileExt) return ContentType.live;
    
    // Detectar patrón SxxExx en el nombre
    final seriesRegex = RegExp(r'S(\d{1,2})E(\d{1,3})', caseSensitive: false);
    if (seriesRegex.hasMatch(name)) return ContentType.series;
    
    return ContentType.movie;
  }

  static ({String name, int season, int episode})? _parseSeriesInfo(String name) {
    final regex = RegExp(r'(.+?)\s*S(\d{1,2})E(\d{1,3})', caseSensitive: false);
    final match = regex.firstMatch(name);
    if (match != null) {
      return (
        name: match.group(1)!.trim(),
        season: int.parse(match.group(2)!),
        episode: int.parse(match.group(3)!),
      );
    }
    return null;
  }

  static String? _extractYear(String name) {
    final regex = RegExp(r'\((\d{4})\)');
    return regex.firstMatch(name)?.group(1);
  }
}
