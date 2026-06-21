import 'dart:io';
import 'package:flutter/foundation.dart';

class SubtitleEntry {
  final Duration start;
  final Duration end;
  final String text;
  SubtitleEntry({required this.start, required this.end, required this.text});
}

class SubtitleService {
  static String? findSrt(String videoPath) {
    final base = videoPath.replaceAll(RegExp(r'\.[^.]+$'), '');
    for (final ext in ['.srt', '.SRT', '.ssa', '.SSA', '.ass', '.ASS']) {
      final f = File('$base$ext');
      if (f.existsSync()) return f.path;
    }
    return null;
  }

  static Future<List<SubtitleEntry>> load(String path) async {
    try {
      final content = await File(path).readAsString();
      final ext = path.split('.').last.toLowerCase();
      final List<SubtitleEntry> entries = await compute(_parseContent, {
        'content': content,
        'ext': ext,
      });
      return entries;
    } catch (_) {
      return [];
    }
  }

  static List<SubtitleEntry> _parseContent(Map<String, String> params) {
    final content = params['content']!;
    final ext = params['ext']!;
    if (ext == 'ssa' || ext == 'ass') {
      return _parseSsa(content);
    } else {
      return _parseSrt(content);
    }
  }

  static List<SubtitleEntry> _parseSrt(String content) {
    final entries = <SubtitleEntry>[];
    final blocks = content.trim().split(RegExp(r'\r?\n\r?\n'));
    for (final block in blocks) {
      final lines = block.trim().split(RegExp(r'\r?\n'));
      if (lines.length < 3) continue;
      try {
        final timeLine = lines[1];
        final parts = timeLine.split(' --> ');
        if (parts.length != 2) continue;
        final start = _parseTime(parts[0].trim());
        final end   = _parseTime(parts[1].trim().split(' ').first);
        final text  = lines.sublist(2).join('\n').replaceAll(RegExp(r'<[^>]*>'), '').trim();
        if (text.isNotEmpty) {
          entries.add(SubtitleEntry(start: start, end: end, text: text));
        }
      } catch (_) {}
    }
    return entries;
  }

  static List<SubtitleEntry> _parseSsa(String content) {
    final entries = <SubtitleEntry>[];
    bool inEvents = false;
    final lines = content.split(RegExp(r'\r?\n'));
    int formatIndex = -1;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('[Events]')) {
        inEvents = true;
        continue;
      }
      if (trimmed.startsWith('[') && !trimmed.startsWith('[Events]')) {
        inEvents = false;
        continue;
      }
      if (!inEvents) continue;
      if (trimmed.startsWith('Format:')) {
        final fields = trimmed.substring(7).split(',').map((e) => e.trim()).toList();
        formatIndex = fields.indexOf('Text');
        continue;
      }
      if (trimmed.startsWith('Dialogue:')) {
        if (formatIndex < 0) continue;
        final parts = _splitDialogue(trimmed.substring(9));
        if (parts.length <= formatIndex) continue;
        try {
          final start = _parseSsaTime(parts[1]);
          final end   = _parseSsaTime(parts[2]);
          String rawText = parts.sublist(formatIndex).join(',');
          String cleanText = _cleanSsaText(rawText);
          if (cleanText.isNotEmpty) {
            entries.add(SubtitleEntry(start: start, end: end, text: cleanText));
          }
        } catch (_) {}
      }
    }
    return entries;
  }

  static List<String> _splitDialogue(String line) {
    final parts = <String>[];
    int depth = 0;
    StringBuffer current = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '{') depth++;
      if (char == '}') depth--;
      if (char == ',' && depth == 0) {
        parts.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    parts.add(current.toString().trim());
    return parts;
  }

  static String _cleanSsaText(String text) {
    String cleaned = text.replaceAll(RegExp(r'\{[^}]*\}'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\\[Nn]'), '\n');
    cleaned = cleaned.trim();
    return cleaned;
  }

  static Duration _parseSsaTime(String s) {
    s = s.trim();
    final parts = s.split(':');
    final hours = int.tryParse(parts[0]) ?? 0;
    final minutes = int.tryParse(parts[1]) ?? 0;
    final secParts = parts[2].split('.');
    final seconds = int.tryParse(secParts[0]) ?? 0;
    final centiseconds = int.tryParse(secParts[1]) ?? 0;
    return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: centiseconds * 10);
  }

  static Duration _parseTime(String s) {
    final normalized = s.replaceAll(',', '.');
    final dotIndex = normalized.lastIndexOf('.');
    int ms = 0;
    String hms = normalized;
    if (dotIndex != -1) {
      ms = int.tryParse(normalized.substring(dotIndex + 1).padRight(3, '0').substring(0, 3)) ?? 0;
      hms = normalized.substring(0, dotIndex);
    }
    final parts = hms.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final sec = int.tryParse(parts[2]) ?? 0;
    return Duration(hours: h, minutes: m, seconds: sec, milliseconds: ms);
  }
}