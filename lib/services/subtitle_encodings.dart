import 'dart:convert';
import 'dart:typed_data';

/// يفك ترميز محتوى نصي (مثل ملفات SRT) بأحد الترميزات الشائعة في
/// ملفات الترجمة العربية القديمة. مكتوب يدوياً بدل الاعتماد على حزمة
/// خارجية، لأن جداول هذين الترميزين صغيرة وثابتة (256 بايت كحد أقصى).
class SubtitleEncodings {
  static const _supported = ['UTF-8', 'UTF-16', 'Windows-1256', 'ISO-8859-6'];

  static List<String> get supportedNames => _supported;

  static String decode(List<int> bytes, String encodingName) {
    switch (encodingName) {
      case 'UTF-16':
        return _decodeUtf16(bytes);
      case 'Windows-1256':
        return _decodeSingleByte(bytes, _windows1256Table);
      case 'ISO-8859-6':
        return _decodeSingleByte(bytes, _iso88596Table);
      case 'UTF-8':
      default:
        return utf8.decode(bytes, allowMalformed: true);
    }
  }

  static String _decodeUtf16(List<int> bytes) {
    final bytesList = Uint8List.fromList(bytes);
    if (bytesList.length >= 2 &&
        bytesList[0] == 0xFF &&
        bytesList[1] == 0xFE) {
      return const Utf8Decoder(allowMalformed: true)
          .convert(_utf16LeToUtf8Bytes(bytesList.sublist(2)));
    }
    if (bytesList.length >= 2 &&
        bytesList[0] == 0xFE &&
        bytesList[1] == 0xFF) {
      return String.fromCharCodes(_utf16BeCodeUnits(bytesList.sublist(2)));
    }
    // بلا BOM: نفترض little-endian (الأكثر شيوعاً على ويندوز).
    return String.fromCharCodes(_utf16LeCodeUnits(bytesList));
  }

  static List<int> _utf16LeCodeUnits(Uint8List bytes) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add(bytes[i] | (bytes[i + 1] << 8));
    }
    return units;
  }

  static List<int> _utf16BeCodeUnits(Uint8List bytes) {
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add((bytes[i] << 8) | bytes[i + 1]);
    }
    return units;
  }

  static List<int> _utf16LeToUtf8Bytes(Uint8List bytes) {
    return utf8.encode(String.fromCharCodes(_utf16LeCodeUnits(bytes)));
  }

  static String _decodeSingleByte(List<int> bytes, List<int> table) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80) {
        buffer.writeCharCode(b);
      } else {
        final mapped = table[b - 0x80];
        buffer.writeCharCode(mapped == 0 ? 0xFFFD : mapped);
      }
    }
    return buffer.toString();
  }

  /// جدول Windows-1256 للنطاق 0x80-0xFF (تعيين Unicode لكل بايت).
  static const List<int> _windows1256Table = [
    0x20AC, 0x067E, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, // 80-87
    0x02C6, 0x2030, 0x0679, 0x2039, 0x0152, 0x0686, 0x0698, 0x0688, // 88-8F
    0x06AF, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, // 90-97
    0x06A9, 0x2122, 0x0691, 0x203A, 0x0153, 0x200C, 0x200D, 0x06BA, // 98-9F
    0x00A0, 0x060C, 0x00A2, 0x00A3, 0x00A4, 0x00A5, 0x00A6, 0x00A7, // A0-A7
    0x00A8, 0x00A9, 0x06BE, 0x00AB, 0x00AC, 0x00AD, 0x00AE, 0x00AF, // A8-AF
    0x00B0, 0x00B1, 0x00B2, 0x00B3, 0x00B4, 0x00B5, 0x00B6, 0x00B7, // B0-B7
    0x00B8, 0x00B9, 0x061B, 0x00BB, 0x00BC, 0x00BD, 0x00BE, 0x061F, // B8-BF
    0x06C1, 0x0621, 0x0622, 0x0623, 0x0624, 0x0625, 0x0626, 0x0627, // C0-C7
    0x0628, 0x0629, 0x062A, 0x062B, 0x062C, 0x062D, 0x062E, 0x062F, // C8-CF
    0x0630, 0x0631, 0x0632, 0x0633, 0x0634, 0x0635, 0x0636, 0x00D7, // D0-D7
    0x0637, 0x0638, 0x0639, 0x063A, 0x0640, 0x0641, 0x0642, 0x0643, // D8-DF
    0x00E0, 0x0644, 0x00E2, 0x0645, 0x0646, 0x0647, 0x0648, 0x00E7, // E0-E7
    0x00E8, 0x00E9, 0x00EA, 0x00EB, 0x0649, 0x064A, 0x00EE, 0x00EF, // E8-EF
    0x064B, 0x064C, 0x064D, 0x064E, 0x00F4, 0x064F, 0x0650, 0x00F7, // F0-F7
    0x0651, 0x00F9, 0x0652, 0x00FB, 0x00FC, 0x200E, 0x200F, 0x06D2, // F8-FF
  ];

  /// جدول ISO-8859-6 للنطاق 0x80-0xFF (0 يعني غير مُعرَّف في المعيار).
  static const List<int> _iso88596Table = [
    0x0080, 0x0081, 0x0082, 0x0083, 0x0084, 0x0085, 0x0086, 0x0087, // 80-87
    0x0088, 0x0089, 0x008A, 0x008B, 0x008C, 0x008D, 0x008E, 0x008F, // 88-8F
    0x0090, 0x0091, 0x0092, 0x0093, 0x0094, 0x0095, 0x0096, 0x0097, // 90-97
    0x0098, 0x0099, 0x009A, 0x009B, 0x009C, 0x009D, 0x009E, 0x009F, // 98-9F
    0x00A0, 0, 0, 0, 0x00A4, 0, 0, 0, // A0-A7
    0, 0, 0, 0, 0x060C, 0x00AD, 0, 0, // A8-AF
    0, 0, 0, 0, 0, 0, 0, 0, // B0-B7
    0, 0, 0, 0x061B, 0, 0, 0, 0x061F, // B8-BF
    0, 0x0621, 0x0622, 0x0623, 0x0624, 0x0625, 0x0626, 0x0627, // C0-C7
    0x0628, 0x0629, 0x062A, 0x062B, 0x062C, 0x062D, 0x062E, 0x062F, // C8-CF
    0x0630, 0x0631, 0x0632, 0x0633, 0x0634, 0x0635, 0x0636, 0x0637, // D0-D7
    0x0638, 0x0639, 0x063A, 0, 0, 0, 0, 0, // D8-DF
    0x0640, 0x0641, 0x0642, 0x0643, 0x0644, 0x0645, 0x0646, 0x0647, // E0-E7
    0x0648, 0x0649, 0x064A, 0x064B, 0x064C, 0x064D, 0x064E, 0x064F, // E8-EF
    0x0650, 0x0651, 0x0652, 0, 0, 0, 0, 0, // F0-F7
    0, 0, 0, 0, 0, 0, 0, 0, // F8-FF
  ];
}
