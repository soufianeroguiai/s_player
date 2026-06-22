import 'package:flutter/foundation.dart';

/// يمثل ملف فيديو واحد في مكتبة التطبيق.
class VideoItem {
  final String id;
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final String folder;
  final Duration duration;
  String? thumbnailPath;
  List<String> subtitleTypes;

  /// يُحدَّث عند اكتشاف مسارات ترجمة مدمجة داخل الفيديو (SRT/ASS/SSA/VTT).
  late final ValueNotifier<List<String>> subtitlesNotifier;

  VideoItem({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.folder,
    required this.duration,
    this.thumbnailPath,
    this.subtitleTypes = const [],
  }) {
    subtitlesNotifier = ValueNotifier(subtitleTypes);
  }

  String get extension => path.split('.').last.toLowerCase();

  String get formattedSize {
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String get formattedDate {
    return '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}';
  }

  /// ينشئ [VideoItem] من مسار ملف موجود على القرص (يُستخدم للملفات
  /// المفتوحة يدوياً أو الموجودة في قائمة "الأخيرة" والتي لم تعد ضمن
  /// نتائج مسح مكتبة الوسائط). يستخدم المسار نفسه كمعرّف لأنه فريد
  /// وثابت، بخلاف hashCode الذي لا يضمن الثبات بين تشغيلات مختلفة.
  factory VideoItem.fromPath({
    required String path,
    required int size,
    required DateTime modified,
  }) {
    final parts = path.split('/');
    return VideoItem(
      id: path,
      path: path,
      name: parts.last,
      size: size,
      modified: modified,
      folder: parts.length > 1 ? parts[parts.length - 2] : '',
      duration: Duration.zero,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'name': name,
      'size': size,
      'modified': modified.millisecondsSinceEpoch,
      'folder': folder,
      'duration': duration.inMilliseconds,
      'thumbnailPath': thumbnailPath,
      'subtitleTypes': subtitleTypes,
    };
  }

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: json['id'] as String,
      path: json['path'] as String,
      name: json['name'] as String,
      size: json['size'] as int,
      modified: DateTime.fromMillisecondsSinceEpoch(json['modified'] as int),
      folder: json['folder'] as String,
      duration: Duration(milliseconds: json['duration'] as int),
      thumbnailPath: json['thumbnailPath'] as String?,
      subtitleTypes: (json['subtitleTypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
