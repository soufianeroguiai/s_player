import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/settings_provider.dart';

/// يبني [TextStyle] الترجمة النهائية من إعدادات المستخدم.
///
/// ملاحظة تقنية: media_kit's SubtitleViewConfiguration لا يوفر سوى
/// [TextStyle]/[TextAlign]/padding، بلا أي وصول لشجرة widgets خاصة
/// بالترجمة. لذلك:
/// - الحدّ الخارجي (Outline) يُحاكى عبر مجموعة ظلال (Shadow) موزَّعة
///   بزوايا متعددة حول النص بنفس إزاحة [outlineWidth]، وهي التقنية
///   القياسية لمحاكاة Stroke في TextStyle بدون فقدان لون التعبئة.
/// - ظل الصندوق (Box Shadow) يُحاكى بظل أكبر امتداداً وأقل حدّة خلف
///   النص (وليس صندوقاً حقيقياً منفصلاً، لعدم توفر هذا المستوى من
///   التحكم في الـ widget الداخلي لـ media_kit).
TextStyle buildSubtitleTextStyle(SettingsProvider s) {
  final shadows = <Shadow>[];

  if (s.outlineEnabled && s.outlineWidth > 0) {
    const steps = 8;
    for (var i = 0; i < steps; i++) {
      final angle = (2 * math.pi / steps) * i;
      shadows.add(Shadow(
        color: s.outlineColor,
        offset: Offset(
          math.cos(angle) * s.outlineWidth,
          math.sin(angle) * s.outlineWidth,
        ),
        blurRadius: 0,
      ));
    }
  }

  if (s.boxShadowEnabled) {
    shadows.add(Shadow(
      color: s.boxShadowColor,
      offset: Offset(s.boxShadowOffsetX, s.boxShadowOffsetY),
      blurRadius: s.boxShadowBlurRadius + 6,
    ));
  }

  if (s.textShadowEnabled) {
    shadows.add(Shadow(
      color: s.textShadowColor,
      offset: Offset(s.textShadowOffsetX, s.textShadowOffsetY),
      blurRadius: s.textShadowBlurRadius,
    ));
  }

  final baseStyle = TextStyle(
    fontSize: s.subtitleFontSize,
    color: s.subtitleColor,
    fontWeight: _fontWeight(s.fontWeightIndex),
    fontStyle: s.subtitleItalic ? FontStyle.italic : FontStyle.normal,
    backgroundColor: s.subtitleBgColor.withOpacity(s.subtitleBgOpacity),
    shadows: shadows.isEmpty ? null : shadows,
  );

  if (_isBuiltInFont(s.fontFamily)) {
    return baseStyle.copyWith(fontFamily: s.fontFamily == 'Roboto' ? null : s.fontFamily);
  }

  try {
    return GoogleFonts.getFont(s.fontFamily, textStyle: baseStyle);
  } catch (_) {
    return baseStyle;
  }
}

bool _isBuiltInFont(String font) {
  const builtIn = {'Roboto', 'monospace', 'sans-serif'};
  return builtIn.contains(font);
}

FontWeight _fontWeight(int index) {
  switch (index) {
    case 0:
      return FontWeight.w300;
    case 1:
      return FontWeight.normal;
    case 2:
      return FontWeight.w500;
    case 3:
      return FontWeight.bold;
    default:
      return FontWeight.normal;
  }
}
