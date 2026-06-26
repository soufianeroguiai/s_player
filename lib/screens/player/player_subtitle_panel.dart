import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:media_kit/media_kit.dart';
import '../../providers/settings_provider.dart';

class SubtitleAppearancePanel extends StatefulWidget {
  final List<SubtitleTrack> subtitleTracks;
  final SubtitleTrack? currentSubtitleTrack;
  final void Function(SubtitleTrack) onTrackSelected;
  final VoidCallback onPickSubtitle;
  final VoidCallback onRemoveExternal;
  final bool hasExternalSubtitle;
  final bool showSubtitles;
  final ValueChanged<bool> onToggleSubtitles;
  final double subtitleSync;
  final ValueChanged<double> onSyncChanged;

  const SubtitleAppearancePanel({
    super.key,
    required this.subtitleTracks,
    required this.currentSubtitleTrack,
    required this.onTrackSelected,
    required this.onPickSubtitle,
    required this.onRemoveExternal,
    required this.hasExternalSubtitle,
    required this.showSubtitles,
    required this.onToggleSubtitles,
    required this.subtitleSync,
    required this.onSyncChanged,
  });

  @override
  State<SubtitleAppearancePanel> createState() => _SubtitleAppearancePanelState();
}

class _SubtitleAppearancePanelState extends State<SubtitleAppearancePanel> {
  int _openSection = -1;

  static const _fontList = [
    ('sans-serif', 'System Default', false),
    ('Roboto', 'Roboto', false),
    ('monospace', 'Monospace', false),
    ('Cairo', 'Cairo', true),
    ('Amiri', 'Amiri', true),
    ('Noto Naskh Arabic', 'Noto Naskh', true),
    ('Noto Kufi Arabic', 'Noto Kufi', true),
    ('Lateef', 'Lateef', true),
    ('Tajawal', 'Tajawal', true),
    ('Scheherazade New', 'Scheherazade', true),
  ];

  void _toggleSection(int index) {
    setState(() {
      _openSection = _openSection == index ? -1 : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SectionTile(
            icon: Symbols.subtitles_rounded,
            title: 'الترجمة',
            isOpen: _openSection == 0,
            onTap: () => _toggleSection(0),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(widget.showSubtitles ? 'مفعلة' : 'متوقفة',
                  style: TextStyle(color: widget.showSubtitles ? cs.primary : Colors.white38, fontSize: 12)),
              Switch(
                value: widget.showSubtitles,
                onChanged: widget.onToggleSubtitles,
                activeColor: cs.primary,
              ),
            ]),
          ),
          if (_openSection == 0) ...[
            const SizedBox(height: 4),
            _buildSubtitleToggleSection(),
          ],

          if (widget.subtitleTracks.isNotEmpty) ...[
            _SectionTile(
              icon: Symbols.video_file_rounded,
              title: 'الترجمات المدمجة',
              isOpen: _openSection == 1,
              onTap: () => _toggleSection(1),
              trailing: Text(
                '${widget.subtitleTracks.length} مسارات',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
            if (_openSection == 1) ...[
              const SizedBox(height: 4),
              _buildEmbeddedTracksSection(),
            ],
          ],

          _SectionTile(
            icon: Symbols.folder_open_rounded,
            title: 'الترجمات الخارجية',
            isOpen: _openSection == 2,
            onTap: () => _toggleSection(2),
            trailing: Text(
              widget.hasExternalSubtitle ? 'ملف خارجي' : 'لا يوجد',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          if (_openSection == 2) ...[
            const SizedBox(height: 4),
            _buildExternalSubtitleSection(),
          ],

          _SectionTile(
            icon: Symbols.palette_rounded,
            title: 'المظهر',
            isOpen: _openSection == 3,
            onTap: () => _toggleSection(3),
            trailing: Text(
              '${s.subtitleFontSize.toInt()}px',
              style: TextStyle(color: cs.primary, fontSize: 12),
            ),
          ),
          if (_openSection == 3) ...[
            const SizedBox(height: 4),
            _buildAppearanceSection(s),
          ],

          _SectionTile(
            icon: Symbols.open_with_rounded,
            title: 'الموضع',
            isOpen: _openSection == 7,
            onTap: () => _toggleSection(7),
            trailing: Text(
              '${s.bottomPadding.toInt()}px / ${s.horizontalMargin.toInt()}px',
              style: TextStyle(color: cs.primary, fontSize: 12),
            ),
          ),
          if (_openSection == 7) ...[
            const SizedBox(height: 4),
            _buildPositionSection(s),
          ],

          _SectionTile(
            icon: Symbols.timeline_rounded,
            title: 'المزامنة',
            isOpen: _openSection == 4,
            onTap: () => _toggleSection(4),
            trailing: Text(
              '${widget.subtitleSync > 0 ? '+' : ''}${widget.subtitleSync.toStringAsFixed(1)}s',
              style: TextStyle(color: cs.primary, fontSize: 12),
            ),
          ),
          if (_openSection == 4) ...[
            const SizedBox(height: 4),
            _buildSyncSection(),
          ],

          _SectionTile(
            icon: Symbols.text_fields_rounded,
            title: 'الترميز',
            isOpen: _openSection == 5,
            onTap: () => _toggleSection(5),
            trailing: Text(
              s.subtitleEncoding,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ),
          if (_openSection == 5) ...[
            const SizedBox(height: 4),
            _buildEncodingSection(s),
          ],

          _SectionTile(
            icon: Symbols.tune_rounded,
            title: 'خيارات متقدمة',
            isOpen: _openSection == 6,
            onTap: () => _toggleSection(6),
          ),
          if (_openSection == 6) ...[
            const SizedBox(height: 4),
            _buildAdvancedSection(s),
          ],
        ],
      ),
    );
  }

  Widget _buildSubtitleToggleSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          widget.showSubtitles ? 'الترجمة مفعلة حالياً' : 'الترجمة متوقفة',
          style: TextStyle(color: widget.showSubtitles ? Theme.of(context).colorScheme.primary : Colors.white38),
        ),
        if (widget.currentSubtitleTrack != null) ...[
          const SizedBox(height: 8),
          Text(
            'المسار النشط: ${widget.currentSubtitleTrack!.title ?? widget.currentSubtitleTrack!.language ?? "غير معروف"}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ]),
    );
  }

  Widget _buildEmbeddedTracksSection() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        ...widget.subtitleTracks.map((track) {
          final name = track.title ?? track.language ?? 'ترجمة';
          final isActive = widget.currentSubtitleTrack == track;
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
          title: const Text('إيقاف', style: TextStyle(color: Colors.white54, fontSize: 13)),
          onTap: () => widget.onTrackSelected(SubtitleTrack.no()),
        ),
      ]),
    );
  }

  Widget _buildExternalSubtitleSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Symbols.folder_open_rounded, color: Colors.white70, size: 18),
          title: const Text('اختيار ملف ترجمة', style: TextStyle(color: Colors.white, fontSize: 13)),
          onTap: widget.onPickSubtitle,
        ),
        if (widget.hasExternalSubtitle)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Symbols.close_rounded, color: Colors.redAccent, size: 18),
            title: const Text('إزالة الترجمة الخارجية', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
            onTap: widget.onRemoveExternal,
          ),
      ]),
    );
  }

  Widget _buildAppearanceSection(SettingsProvider s) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SettingRow(label: 'حجم الخط', value: '${s.subtitleFontSize.toInt()} px'),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: cs.primary,
            inactiveTrackColor: Colors.white12,
            thumbColor: cs.primary,
          ),
          child: Slider(
            value: s.subtitleFontSize,
            min: 12,
            max: 80,
            onChanged: s.setSubtitleFontSize,
          ),
        ),
        const SizedBox(height: 14),
        _SettingRow(label: 'نوع الخط', value: s.fontFamily),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _fontList.length,
            itemBuilder: (_, i) {
              final (id, label, isGoogle) = _fontList[i];
              final sel = s.fontFamily == id;
              return GestureDetector(
                onTap: () => s.setFontFamily(id),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? cs.primary.withOpacity(0.2) : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? cs.primary : Colors.white24, width: sel ? 1.5 : 1),
                  ),
                  child: Text(label, style: TextStyle(color: sel ? cs.primary : Colors.white54, fontSize: 11)),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        _SettingRow(label: 'لون الخط'),
        const SizedBox(height: 6),
        _ColorPickerRow(
          currentColor: s.subtitleColor,
          onColorChanged: s.setSubtitleColor,
        ),
        const SizedBox(height: 14),
        Row(children: [
          const Expanded(child: _SettingRow(label: 'خلفية النص')),
          Switch(
            value: s.subtitleBgOpacity > 0,
            onChanged: (v) => s.setSubtitleBgOpacity(v ? 0.65 : 0.0),
            activeColor: cs.primary,
          ),
        ]),
        if (s.subtitleBgOpacity > 0) ...[
          const SizedBox(height: 6),
          _ColorPickerRow(
            currentColor: s.subtitleBgColor,
            onColorChanged: s.setSubtitleBgColor,
          ),
          const SizedBox(height: 6),
          _SettingRow(label: 'الشفافية', value: '${(s.subtitleBgOpacity * 100).toInt()}%'),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: cs.primary,
              inactiveTrackColor: Colors.white12,
              thumbColor: cs.primary,
            ),
            child: Slider(
              value: s.subtitleBgOpacity,
              min: 0.1,
              max: 1.0,
              onChanged: s.setSubtitleBgOpacity,
            ),
          ),
        ],
        const SizedBox(height: 14),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('خط مائل', style: TextStyle(color: Colors.white, fontSize: 13)),
          value: s.subtitleItalic,
          onChanged: s.setSubtitleItalic,
          activeColor: cs.primary,
        ),
      ]),
    );
  }

  Widget _buildPositionSection(SettingsProvider s) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SettingRow(label: 'الارتفاع عن الأسفل', value: '${s.bottomPadding.toInt()} px'),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: cs.primary,
            inactiveTrackColor: Colors.white12,
            thumbColor: cs.primary,
          ),
          child: Slider(
            value: s.bottomPadding,
            min: 0,
            max: 300,
            onChanged: s.setBottomPadding,
          ),
        ),
        const SizedBox(height: 14),
        _SettingRow(label: 'الهامش الأفقي', value: '${s.horizontalMargin.toInt()} px'),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            activeTrackColor: cs.primary,
            inactiveTrackColor: Colors.white12,
            thumbColor: cs.primary,
          ),
          child: Slider(
            value: s.horizontalMargin,
            min: 0,
            max: 120,
            onChanged: s.setHorizontalMargin,
          ),
        ),
      ]),
    );
  }

  Widget _buildSyncSection() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SettingRow(
          label: 'تأخير الترجمة',
          value: '${widget.subtitleSync > 0 ? '+' : ''}${widget.subtitleSync.toStringAsFixed(1)} ثانية',
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
            value: widget.subtitleSync,
            min: -5.0,
            max: 5.0,
            divisions: 100,
            onChanged: widget.onSyncChanged,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'القيمة السالبة تُقدم الترجمة، والموجبة تؤخرها',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
        ),
      ]),
    );
  }

  Widget _buildEncodingSection(SettingsProvider s) {
    const encodings = ['UTF-8', 'UTF-16', 'Windows-1256', 'ISO-8859-6'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: encodings.map((enc) {
        final isSelected = s.subtitleEncoding == enc;
        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(enc, style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white, fontSize: 13)),
          trailing: isSelected ? Icon(Symbols.check_rounded, color: Theme.of(context).colorScheme.primary, size: 18) : null,
          onTap: () => s.setSubtitleEncoding(enc),
        );
      }).toList()),
    );
  }

  Widget _buildAdvancedSection(SettingsProvider s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: const Text('حفظ الإعدادات كافتراضية', style: TextStyle(color: Colors.white, fontSize: 13)),
        subtitle: const Text('تنطبق على جميع الفيديوهات', style: TextStyle(color: Colors.white38, fontSize: 11)),
        value: s.rememberPosition,
        onChanged: s.setRememberPosition,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
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
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isOpen ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOpen ? cs.primary.withOpacity(0.5) : Colors.white.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(children: [
            Icon(icon, size: 18, color: isOpen ? cs.primary : Colors.white54),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                    color: isOpen ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: isOpen ? FontWeight.w700 : FontWeight.w500,
                  )),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
            const SizedBox(width: 4),
            Icon(isOpen ? Symbols.expand_less_rounded : Symbols.expand_more_rounded,
                color: isOpen ? cs.primary : Colors.white38, size: 20),
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

class _ColorPickerRow extends StatelessWidget {
  final Color currentColor;
  final ValueChanged<Color> onColorChanged;

  const _ColorPickerRow({required this.currentColor, required this.onColorChanged});

  static const _colors = [
    Colors.white, Colors.yellow, Color(0xFFFFE680),
    Color(0xFF80FF80), Color(0xFF80D4FF), Color(0xFFFFB3B3),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      ..._colors.map((c) => GestureDetector(
        onTap: () => onColorChanged(c),
        child: Container(
          margin: const EdgeInsets.only(right: 6),
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: c,
            shape: BoxShape.circle,
            border: Border.all(
              color: currentColor.value == c.value ? Colors.white : Colors.white30,
              width: currentColor.value == c.value ? 2.5 : 1,
            ),
          ),
        ),
      )),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: () async {
          final picked = await showColorPickerDialog(
            context,
            currentColor,
            title: const Text('اختر لوناً', style: TextStyle(fontWeight: FontWeight.bold)),
          );
          onColorChanged(picked);
        },
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white38),
            gradient: const SweepGradient(colors: [
              Colors.red, Colors.yellow, Colors.green,
              Colors.cyan, Colors.blue, Colors.purple, Colors.red,
            ]),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
        ),
      ),
    ]);
  }
}