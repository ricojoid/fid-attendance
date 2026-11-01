import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Returns a stable [ImageProvider] for an avatar string (data URI, URL or path).
///
/// Previously every build did `MemoryImage(base64Decode(...))`, which decodes
/// the base64 string AND creates a new provider identity each frame, so Flutter
/// re-decodes the bitmap and the avatar flickers. Here each distinct string is
/// decoded once and the same provider instance is reused (small LRU).
class AvatarCache {
  AvatarCache._();

  static const int _max = 64;
  static final LinkedHashMap<String, ImageProvider> _cache = LinkedHashMap();

  static ImageProvider? provider(String? source, {int? cacheWidth = 256}) {
    if (source == null || source.isEmpty) return null;
    final hit = _cache.remove(source);
    if (hit != null) {
      _cache[source] = hit; // refresh LRU position
      return hit;
    }

    ImageProvider? p;
    try {
      if (source.startsWith('data:image')) {
        p = MemoryImage(base64Decode(source.split(',').last));
      } else if (kIsWeb || source.startsWith('http') || source.startsWith('blob:')) {
        p = NetworkImage(source);
      } else {
        p = FileImage(File(source));
      }
    } catch (_) {
      return null;
    }
    // Decode at display size, not the original photo resolution.
    if (cacheWidth != null) p = ResizeImage(p, width: cacheWidth, policy: ResizeImagePolicy.fit);

    _cache[source] = p;
    if (_cache.length > _max) _cache.remove(_cache.keys.first);
    return p;
  }
}
