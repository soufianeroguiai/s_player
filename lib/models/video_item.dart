class VideoItem {
  final String id;
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final String folder;
  final Duration duration;
  List<int>? thumbnail;

  VideoItem({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.folder,
    required this.duration,
    this.thumbnail,
  });

  String get extension => path.split('.').last.toLowerCase();

  String get formattedSize {
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(0)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String get formattedDate {
    return '${modified.year}-${modified.month.toString().padLeft(2,'0')}-${modified.day.toString().padLeft(2,'0')}';
  }

  // ✅ تحويل الكائن إلى JSON (لحفظه في ملف cache)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'path': path,
      'name': name,
      'size': size,
      'modified': modified.millisecondsSinceEpoch,
      'folder': folder,
      'duration': duration.inMilliseconds,
      // لا نخزّن الصورة المصغرة (thumbnail) لأنها بيانات ثنائية كبيرة
    };
  }

  // ✅ إنشاء كائن من JSON (لاسترجاعه من ملف cache)
  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: json['id'] as String,
      path: json['path'] as String,
      name: json['name'] as String,
      size: json['size'] as int,
      modified: DateTime.fromMillisecondsSinceEpoch(json['modified'] as int),
      folder: json['folder'] as String,
      duration: Duration(milliseconds: json['duration'] as int),
      // thumbnail سيتم تحميله لاحقاً عند الحاجة
    );
  }
}