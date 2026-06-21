class VideoFile {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final String folder;
  Duration? duration;

  VideoFile({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.folder,
    this.duration,
  });

  String get extension => path.split('.').last.toLowerCase();

  String get formattedSize {
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String get formattedDuration {
    if (duration == null) return '--:--';
    final h = duration!.inHours;
    final m = duration!.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = duration!.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  String get formattedDate {
    return '${modified.year}-${modified.month.toString().padLeft(2, '0')}-${modified.day.toString().padLeft(2, '0')}';
  }
}