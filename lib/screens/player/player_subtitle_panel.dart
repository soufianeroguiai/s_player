import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import '../../providers/settings_provider.dart';

class LiveSubtitleSettings extends StatelessWidget {
  final bool showSubtitles;
  final List<SubtitleTrack> subtitleTracks;
  final SubtitleTrack? currentTrack;
  final double subtitleSync;
  final ValueChanged<bool> onToggleSubtitles;
  final void Function(SubtitleTrack) onTrackSelected;
  final ValueChanged<double> onSyncChanged;
  final VoidCallback onPickSubtitle;
  final VoidCallback onClose;

  const LiveSubtitleSettings({
    super.key,
    required this.showSubtitles,
    required this.subtitleTracks,
    required this.currentTrack,
    required this.subtitleSync,
    required this.onToggleSubtitles,
    required this.onTrackSelected,
    required this.onSyncChanged,
    required this.onPickSubtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE5232323),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الترجمة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Symbols.close_rounded, color: Colors.white70), onPressed: onClose),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Expanded(child: Text('تفعيل', style: TextStyle(color: Colors.white))),
                Switch(value: showSubtitles, onChanged: onToggleSubtitles, activeColor: cs.primary),
              ]),
              if (subtitleTracks.isNotEmpty) ...[
                const Divider(color: Colors.white24),
                const Text('المسارات', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                ...subtitleTracks.map((track) => ListTile(
                  dense: true,
                  title: Text(track.title ?? track.language ?? 'ترجمة', style: const TextStyle(color: Colors.white)),
                  trailing: currentTrack == track ? Icon(Symbols.check_rounded, color: cs.primary) : null,
                  onTap: () => onTrackSelected(track),
                )),
              ],
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Symbols.folder_open_rounded, color: Colors.white70),
                title: const Text('ملف خارجي', style: TextStyle(color: Colors.white)),
                onTap: onPickSubtitle,
              ),
              const Divider(color: Colors.white24),
              Row(children: [
                const Text('تزامن', style: TextStyle(color: Colors.white)),
                const SizedBox(width: 8),
                Text('${subtitleSync.toStringAsFixed(1)}s', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
              ]),
              Slider(
                value: subtitleSync, min: -5.0, max: 5.0, divisions: 100,
                onChanged: onSyncChanged, activeColor: cs.primary,
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerRight,
                child: Text('المظهر', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              const SubtitleAppearanceLive(),
            ],
          ),
        ),
      ),
    );
  }
}

class SubtitleAppearanceLive extends StatelessWidget {
  const SubtitleAppearanceLive({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Row(children: [
        const Icon(Symbols.format_size_rounded, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Text('الحجم', style: TextStyle(color: Colors.white))),
        Text('${s.subtitleFontSize.toInt()}', style: TextStyle(color: cs.primary)),
      ]),
      Slider(
        value: s.subtitleFontSize, min: 12, max: 80,
        onChanged: s.setSubtitleFontSize,
        activeColor: cs.primary,
      ),
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Symbols.format_paint_rounded, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Text('اللون', style: TextStyle(color: Colors.white))),
        GestureDetector(
          onTap: () => _showColorPicker(context, s.subtitleColor, s.setSubtitleColor),
          child: Container(width: 24, height: 24, decoration: BoxDecoration(color: s.subtitleColor, shape: BoxShape.circle)),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Symbols.format_italic_rounded, color: Colors.white70, size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Text('مائل', style: TextStyle(color: Colors.white))),
        Switch(value: s.subtitleItalic, onChanged: s.setSubtitleItalic, activeColor: cs.primary),
      ]),
    ]);
  }

  void _showColorPicker(BuildContext ctx, Color current, ValueChanged<Color> onChanged) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('اختر لون'),
        content: SizedBox(
          width: 280,
          height: 280,
          child: GridView.count(
            crossAxisCount: 5,
            children: [Colors.white, Colors.yellow, Colors.cyan, Colors.lime, Colors.orange, Colors.red, Colors.green, Colors.blue, Colors.purple, Colors.pink].map((c) => GestureDetector(
              onTap: () { onChanged(c); Navigator.pop(ctx); },
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: current == c ? Colors.white : Colors.transparent, width: 3)),
              ),
            )).toList(),
          ),
        ),
      ),
    );
  }
}