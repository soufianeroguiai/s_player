import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VideoFitMode { contain, cover, fill }

BoxFit getBoxFit(VideoFitMode mode) {
  switch (mode) {
    case VideoFitMode.contain:
      return BoxFit.contain;
    case VideoFitMode.cover:
      return BoxFit.cover;
    case VideoFitMode.fill:
      return BoxFit.fill;
  }
}

String modeName(VideoFitMode mode) {
  switch (mode) {
    case VideoFitMode.contain:
      return 'احتواء';
    case VideoFitMode.cover:
      return 'تغطية';
    case VideoFitMode.fill:
      return 'تمديد';
  }
}

class VideoFitSettings {
  static const _key = 'video_fit_mode';

  static Future<void> save(VideoFitMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, mode.index);
  }

  static Future<VideoFitMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_key) ?? 0;
    if (index < 0 || index >= VideoFitMode.values.length) {
      return VideoFitMode.contain;
    }
    return VideoFitMode.values[index];
  }
}
