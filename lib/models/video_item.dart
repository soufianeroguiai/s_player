class VideoItem {
  final String id;
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final String folder;
  final Duration duration;
  String? thumbnailPath;

  VideoItem({
    required this.id,
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.folder,
    required this.duration,
    this.thumbnailPath,
  });

  String get extension => path.split('.').last.toLowerCase();

  String get formattedSize {
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(0)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'name': name,
        'size': size,
        'modified': modified.millisecondsSinceEpoch,
        'folder': folder,
        'duration': duration.inMilliseconds,
        'thumbnailPath': thumbnailPath,
      };

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
        id: json['id'],
        path: json['path'],
        name: json['name'],
        size: json['size'],
        modified: DateTime.fromMillisecondsSinceEpoch(json['modified']),
        folder: json['folder'],
        duration: Duration(milliseconds: json['duration']),
        thumbnailPath: json['thumbnailPath'],
      );
}
