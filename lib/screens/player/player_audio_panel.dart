import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:media_kit/media_kit.dart';

class AudioSettingsPanel extends StatefulWidget {
  final Player player;
  final double volumeLevel;
  final ValueChanged<double> onVolumeChanged;
  final List<AudioTrack> audioTracks;
  final AudioTrack? currentAudioTrack;
  final void Function(AudioTrack) onTrackSelected;
  final double audioDelay;
  final ValueChanged<double> onAudioDelayChanged;
  final VoidCallback onClose;

  const AudioSettingsPanel({
    super.key,
    required this.player,
    required this.volumeLevel,
    required this.onVolumeChanged,
    required this.audioTracks,
    required this.currentAudioTrack,
    required this.onTrackSelected,
    required this.audioDelay,
    required this.onAudioDelayChanged,
    required this.onClose,
  });

  @override
  State<AudioSettingsPanel> createState() => _AudioSettingsPanelState();
}

class _AudioSettingsPanelState extends State<AudioSettingsPanel> {
  int _openSection = -1;
  bool _muted = false;

  void _toggleSection(int index) {
    setState(() {
      _openSection = _openSection == index ? -1 : index;
    });
  }

  bool get _hasMultipleTracks => widget.audioTracks.length > 1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_hasMultipleTracks) ...[
            _SectionTile(
              icon: Symbols.audiotrack_rounded,
              title: 'مسار الصوت',
              isOpen: _openSection == 0,
              onTap: () => _toggleSection(0),
              trailing: Text(
                widget.currentAudioTrack?.language ?? 'مسار افتراضي',
                style: TextStyle(color: cs.primary, fontSize: 12),
              ),
            ),
            if (_openSection == 0) ...[
              const SizedBox(height: 4),
              _buildAudioTrackSection(),
            ],
          ],

          _SectionTile(
            icon: Symbols.volume_up_rounded,
            title: 'مستوى الصوت',
            isOpen: _openSection == 1,
            onTap: () => _toggleSection(1),
            trailing: Text(
              '${(widget.volumeLevel * 100).round()}%',
              style: TextStyle(color: cs.primary, fontSize: 12),
            ),
          ),
          if (_openSection == 1) ...[
            const SizedBox(height: 4),
            _buildVolumeSection(),
          ],

          _SectionTile(
            icon: Symbols.timeline_rounded,
            title: 'مزامنة الصوت',
            isOpen: _openSection == 4,
            onTap: () => _toggleSection(4),
            trailing: Text(
              '${widget.audioDelay > 0 ? '+' : ''}${widget.audioDelay.toStringAsFixed(0)} ms',
              style: TextStyle(color: cs.primary, fontSize: 12),
            ),
          ),
          if (_openSection == 4) ...[
            const SizedBox(height: 4),
            _buildAudioSyncSection(),
          ],

          _SectionTile(
            icon: Symbols.info_rounded,
            title: 'معلومات الصوت',
            isOpen: _openSection == 8,
            onTap: () => _toggleSection(8),
          ),
          if (_openSection == 8) ...[
            const SizedBox(height: 4),
            _buildAudioInfoSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioTrackSection() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: [
        ...widget.audioTracks.map((track) {
          final name = track.title ?? track.language ?? 'مسار صوتي';
          final isActive = widget.currentAudioTrack == track;
          return ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            title: Text(name, style: TextStyle(color: isActive ? cs.primary : Colors.white, fontSize: 13)),
            trailing: isActive ? Icon(Symbols.check_rounded, color: cs.primary, size: 18) : null,
            onTap: () => widget.onTrackSelected(track),
          );
        }),
        const Divider(color: Colors.white24, height: 1),
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: const Text('إيقاف الصوت', style: TextStyle(color: Colors.white54, fontSize: 13)),
          onTap: () => widget.onTrackSelected(AudioTrack.no()),
        ),
      ]),
    );
  }

  Widget _buildVolumeSection() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SettingRow(label: 'مستوى الصوت', value: '${(widget.volumeLevel * 100).round()}%'),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: cs.primary,
            inactiveTrackColor: Colors.white12,
            thumbColor: cs.primary,
          ),
          child: Slider(
            value: widget.volumeLevel.clamp(0.0, 2.0),
            min: 0.0,
            max: 2.0,
            divisions: 20,
            onChanged: widget.onVolumeChanged,
          ),
        ),
        const SizedBox(height: 12),
        _SettingRow(label: 'تضخيم الصوت', value: '${widget.volumeLevel > 1.0 ? (widget.volumeLevel * 100).round() : 100}%'),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: widget.volumeLevel > 1.0 ? Colors.orange : cs.primary,
            inactiveTrackColor: Colors.white12,
            thumbColor: widget.volumeLevel > 1.0 ? Colors.orange : cs.primary,
          ),
          child: Slider(
            value: widget.volumeLevel.clamp(1.0, 2.0),
            min: 1.0,
            max: 2.0,
            divisions: 10,
            onChanged: (v) => widget.onVolumeChanged(v),
          ),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('كتم الصوت', style: TextStyle(color: Colors.white, fontSize: 13)),
          value: _muted,
          onChanged: (v) {
            setState(() => _muted = v);
            widget.player.setVolume(v ? 0 : widget.volumeLevel * 100.0);
          },
          activeColor: cs.primary,
        ),
      ]),
    );
  }

  Widget _buildAudioSyncSection() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SettingRow(
          label: 'تأخير الصوت',
          value: '${widget.audioDelay > 0 ? '+' : ''}${widget.audioDelay.toStringAsFixed(0)} ms',
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: cs.primary,
            inactiveTrackColor: Colors.white12,
            thumbColor: cs.primary,
          ),
          child: Slider(
            value: widget.audioDelay,
            min: -500.0,
            max: 500.0,
            divisions: 50,
            onChanged: widget.onAudioDelayChanged,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'القيمة السالبة تُقدم الصوت، والموجبة تؤخره',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: () => widget.onAudioDelayChanged(0),
            icon: const Icon(Symbols.restart_alt_rounded, size: 18),
            label: const Text('إعادة الضبط'),
            style: TextButton.styleFrom(foregroundColor: cs.primary),
          ),
        ),
      ]),
    );
  }

  Widget _buildAudioInfoSection() {
    final track = widget.currentAudioTrack;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: track != null
          ? Column(children: [
              _infoTile('اللغة', track.language ?? 'غير معروف'),
              _infoTile('العنوان', track.title ?? 'غير معروف'),
              _infoTile('الترميز', track.codec ?? 'غير معروف'),
              _infoTile('القناة', track.channels != null ? '${track.channels}' : 'غير معروف'),
              _infoTile('معدل البت', track.bitrate != null ? '${track.bitrate} kbps' : 'غير معروف'),
            ])
          : const Text('لا توجد معلومات صوتية', style: TextStyle(color: Colors.white38)),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Flexible(
          child: Text(
            value,
            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
            textAlign: TextAlign.left,
          ),
        ),
      ]),
    );
  }
}

class _SectionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isOpen;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SectionTile({
    required this.icon,
    required this.title,
    required this.isOpen,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isOpen ? Colors.black.withOpacity(0.8) : Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOpen ? cs.primary.withOpacity(0.6) : Colors.white.withOpacity(0.08),
          width: isOpen ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isOpen ? cs.primary.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: isOpen ? cs.primary : Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                    color: isOpen ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: isOpen ? FontWeight.bold : FontWeight.w600,
                  )),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
            const SizedBox(width: 8),
            Icon(isOpen ? Symbols.expand_less_rounded : Symbols.expand_more_rounded,
                color: isOpen ? cs.primary : Colors.white54, size: 22),
          ]),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String? value;
  const _SettingRow({required this.label, this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      if (value != null)
        Text(value!, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }
}
