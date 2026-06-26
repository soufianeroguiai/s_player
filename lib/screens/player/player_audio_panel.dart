import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:media_kit/media_kit.dart';

class LiveAudioSettings extends StatelessWidget {
  final double volumeLevel;
  final List<AudioTrack> audioTracks;
  final AudioTrack? currentTrack;
  final ValueChanged<double> onVolumeChanged;
  final void Function(AudioTrack) onTrackSelected;
  final VoidCallback onClose;

  const LiveAudioSettings({
    super.key,
    required this.volumeLevel,
    required this.audioTracks,
    required this.currentTrack,
    required this.onVolumeChanged,
    required this.onTrackSelected,
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
                  const Text('الصوت', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Symbols.close_rounded, color: Colors.white70), onPressed: onClose),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Symbols.volume_up_rounded, color: Colors.white70),
                const SizedBox(width: 8),
                const Expanded(child: Text('مستوى الصوت', style: TextStyle(color: Colors.white))),
                Text('${(volumeLevel * 100).round()}%', style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
              ]),
              Slider(
                value: volumeLevel.clamp(0.5, 2.0), min: 0.5, max: 2.0, divisions: 30,
                onChanged: onVolumeChanged, activeColor: cs.primary,
              ),
              if (audioTracks.isNotEmpty) ...[
                const Divider(color: Colors.white24),
                const Text('المسارات الصوتية', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                ...audioTracks.map((track) => ListTile(
                  dense: true,
                  title: Text(track.title ?? track.language ?? 'مسار صوتي', style: const TextStyle(color: Colors.white)),
                  trailing: currentTrack == track ? Icon(Symbols.check_rounded, color: cs.primary) : null,
                  onTap: () => onTrackSelected(track),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}