import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class PlayerSettingsPanel extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onCaptureScreenshot;
  final VoidCallback onToggleFit;
  final VoidCallback onToggleOrientation;
  final VoidCallback onEnterPip;
  final VoidCallback onShowInfo;
  final VoidCallback? onSleepTimer;
  final VoidCallback? onShowSpeedPicker;
  final VoidCallback? onToggleRememberPosition;
  final bool rememberPosition;
  final double currentSpeed;
  final String currentFitMode;
  final VoidCallback onClose;

  const PlayerSettingsPanel({
    super.key,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
    required this.onCaptureScreenshot,
    required this.onToggleFit,
    required this.onToggleOrientation,
    required this.onEnterPip,
    required this.onShowInfo,
    this.onSleepTimer,
    this.onShowSpeedPicker,
    this.onToggleRememberPosition,
    this.rememberPosition = false,
    this.currentSpeed = 1.0,
    this.currentFitMode = 'احتواء',
    required this.onClose,
  });

  @override
  State<PlayerSettingsPanel> createState() => _PlayerSettingsPanelState();
}

class _PlayerSettingsPanelState extends State<PlayerSettingsPanel> {
  int _openSection = -1;

  void _toggleSection(int index) {
    setState(() {
      _openSection = _openSection == index ? -1 : index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ❤️ المفضلة (أيقونة موحدة)
          _ListTile(
            icon: Symbols.favorite_rounded,
            title: widget.isFavorite ? 'إزالة من المفضلة' : 'إضافة للمفضلة',
            iconColor: widget.isFavorite ? Colors.amber : Colors.white70,
            onTap: widget.onToggleFavorite,
          ),

          const SizedBox(height: 4),

          // 📃 Playlist
          _ListTile(
            icon: Symbols.playlist_add_rounded,
            title: 'إضافة إلى قائمة التشغيل',
            onTap: widget.onAddToPlaylist,
          ),

          const SizedBox(height: 4),

          // 📷 Screenshot
          _ListTile(
            icon: Symbols.camera_rounded,
            title: 'لقطة شاشة',
            onTap: widget.onCaptureScreenshot,
          ),

          const SizedBox(height: 8),

          // 📐 Aspect Ratio
          _SectionTile(
            icon: Symbols.aspect_ratio_rounded,
            title: 'نسبة العرض',
            isOpen: _openSection == 1,
            onTap: () => _toggleSection(1),
            trailing: Text(
              widget.currentFitMode,
              style: TextStyle(color: cs.primary, fontSize: 12),
            ),
          ),
          if (_openSection == 1) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                _ListTile(
                  icon: Symbols.fit_screen_rounded,
                  title: 'احتواء',
                  iconColor: widget.currentFitMode == 'احتواء' ? cs.primary : Colors.white70,
                  onTap: () {
                    widget.onToggleFit();
                    _toggleSection(1);
                  },
                ),
                _ListTile(
                  icon: Symbols.fullscreen_rounded,
                  title: 'تغطية',
                  iconColor: widget.currentFitMode == 'تغطية' ? cs.primary : Colors.white70,
                  onTap: () {
                    widget.onToggleFit();
                    _toggleSection(1);
                  },
                ),
                _ListTile(
                  icon: Symbols.zoom_out_map_rounded,
                  title: 'تمديد',
                  iconColor: widget.currentFitMode == 'تمديد' ? cs.primary : Colors.white70,
                  onTap: () {
                    widget.onToggleFit();
                    _toggleSection(1);
                  },
                ),
              ]),
            ),
          ],

          const SizedBox(height: 4),

          // 🔄 Rotate
          _ListTile(
            icon: Symbols.screen_rotation_rounded,
            title: 'تدوير الشاشة',
            onTap: widget.onToggleOrientation,
          ),

          const SizedBox(height: 4),

          // 🪟 نافذة عائمة
          _ListTile(
            icon: Symbols.picture_in_picture_rounded,
            title: 'نافذة عائمة (PiP)',
            onTap: widget.onEnterPip,
          ),

          const SizedBox(height: 4),

          // ⏲ Sleep Timer
          if (widget.onSleepTimer != null) ...[
            _ListTile(
              icon: Symbols.bedtime_rounded,
              title: 'مؤقت النوم',
              onTap: widget.onSleepTimer!,
            ),
            const SizedBox(height: 4),
          ],

          // 📄 معلومات الفيديو
          _ListTile(
            icon: Symbols.info_rounded,
            title: 'معلومات الفيديو',
            onTap: widget.onShowInfo,
          ),

          const SizedBox(height: 8),

          // ⚙ إعدادات المشغل
          _SectionTile(
            icon: Symbols.settings_rounded,
            title: 'إعدادات المشغل',
            isOpen: _openSection == 2,
            onTap: () => _toggleSection(2),
          ),
          if (_openSection == 2) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(children: [
                if (widget.onShowSpeedPicker != null)
                  _ListTile(
                    icon: Symbols.speed_rounded,
                    title: 'سرعة التشغيل (${widget.currentSpeed}x)',
                    onTap: widget.onShowSpeedPicker!,
                  ),
                if (widget.onToggleRememberPosition != null)
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تذكر موضع التشغيل', style: TextStyle(color: Colors.white, fontSize: 13)),
                    value: widget.rememberPosition,
                    onChanged: (_) => widget.onToggleRememberPosition!(),
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final VoidCallback onTap;

  const _ListTile({
    required this.icon,
    required this.title,
    this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: iconColor ?? Colors.white70, size: 20),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13)),
        onTap: onTap,
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