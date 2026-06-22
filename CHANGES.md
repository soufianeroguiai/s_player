# سجل التعديلات — SR Player (نسخة مُصححة ومُعاد هيكلتها)

## 1) إعادة الهيكلة

```
lib/
├── app/permission_gate.dart           شاشة طلب الصلاحيات (مستخرجة من main.dart)
├── main.dart                          نقطة الدخول فقط
├── models/video_item.dart             + factory fromPath() موحّدة
├── providers/
│   ├── settings_provider.dart         منظَّفة من الإعدادات الميتة
│   └── library_provider.dart
├── services/
│   ├── thumbnail_service.dart         أعيدت كتابتها: photo_manager أولاً
│   ├── subtitle_service.dart          + دعم الترميز الفعلي + compute()
│   ├── subtitle_encodings.dart        جديد: فك ترميز يدوي (Windows-1256/ISO-8859-6)
│   └── pip_service.dart               + تتبّع حالة PiP حقيقية
├── screens/
│   ├── home/                          مقسَّمة: home_screen / home_tabs / home_search_delegate
│   ├── player/                        مقسَّمة: screen / controls / indicators /
│   │                                   audio_panel / subtitle_panel / fit_mode /
│   │                                   subtitle_style_builder
│   ├── settings/                      مقسَّمة: screen / dialogs / widgets
│   └── info_screen.dart
├── theme/app_theme.dart               تعليقات يتيمة محذوفة
└── widgets/                           video_card / video_thumbnail_loader
```

## 2) أخطاء وظيفية تم إصلاحها

| # | المشكلة | الإصلاح |
|---|---|---|
| 1 | الصور المصغّرة بطيئة (فتح `Player()` كامل لكل فيديو) | `ThumbnailService` تستخدم الآن `AssetEntity.thumbnailDataWithSize` (سريعة، native)، وتلجأ لـ media_kit فقط للملفات المفتوحة يدوياً بلا AssetEntity |
| 2 | تكبير الصوت (Audio Boost) غير مربوط بالمشغل | `AudioBoostSection` أصبحت تُستدعى فعلياً من `player_screen.dart` وتتحكم في نفس `_volumeLevel` المستخدَم في الإيماءات |
| 3 | مزامنة الترجمة بصرية فقط | تُطبَّق الآن فعلياً عبر إعادة بناء توقيت SRT وإعادة تحميله في المشغل |
| 4 | `preferredAudioLanguage` غير مُطبَّقة | أُضيفت `_applyPreferredAudioLanguage()` بنفس منطق لغة الترجمة المفضّلة |
| 5 | وضع PiP المخصص لا يُفعَّل أبداً | `MainActivity.kt` يرسل الآن `onPipModeChanged` فعلياً عبر MethodChannel، و`PipService.isInPipMode` تعكس الحالة الحقيقية |
| 6 | Outline / Box-Shadow كود ميت بلا واجهة | فُعِّلت بالكامل: واجهة في إعدادات الترجمة (داخل المشغل وفي شاشة الإعدادات)، ومُطبَّقة فعلياً عبر محاكاة ظلال متعددة الاتجاهات (القيد التقني لـ media_kit موثَّق في الكود) |
| 7 | أزرار بلا وظيفة (`audioPlayerEngine`, `audioOutput` غير المطبَّقتين فعلياً) | حُذفت هذه الإعدادات بالكامل بدل ترك أزرار خادعة |
| 8 | خطوط الترجمة العربية غير موجودة | استُبدلت بحزمة `google_fonts` (تحميل ديناميكي حقيقي بدل أسماء بلا ملفات) |
| 9 | ترميز ملفات SRT يُقرأ بـ UTF-8 دائماً | `SubtitleService.load()` يستخدم الآن `subtitle_encodings.dart` لدعم Windows-1256/ISO-8859-6/UTF-16 فعلياً |
| 10 | `path.hashCode` كمعرّف غير مضمون الثبات | استُبدل بالمسار نفسه كمفتاح في `LibraryProvider.savePosition/getPosition`، وبـ `VideoItem.fromPath` موحّدة |
| 11 | `Color.value` المهجورة | استُبدلت بـ `Color.toARGB32()` |

## 3) كود ميت تم حذفه

- `models/video_file.dart` و `services/media_scanner.dart` (غير مستخدَمين، حلّ محلهما `VideoItem`/`LibraryProvider`)
- `services/recent_files_service.dart` (مكرر مع `LibraryProvider.recentPaths`)
- إعدادات `audioOutput`, `audioPlayerEngine`, `defaultVolume`, `showVolumePanel`, `pauseOnHeadphonesDisconnect`, `fadeInStart`, `fadeInSeek`, `bluetoothAudioDelayMs`, `audioPassthrough`, `audioRate`, `subtitleHwAcceleration`, `subtitleFontsFolder` من `SettingsProvider` (كانت محفوظة بلا أي تأثير فعلي في المشغل)

## 4) Android / Build

- حذف صلاحيات زائدة: `READ_EXTERNAL_STORAGE`, `WRITE_EXTERNAL_STORAGE`, `WRITE_SETTINGS`, `requestLegacyExternalStorage` (غير ضرورية مع `READ_MEDIA_VIDEO`/`READ_MEDIA_AUDIO` + photo_manager)
- توحيد إصدار Kotlin بين `gradle.properties` (كان 2.0.0) و`settings.gradle.kts`/`build.gradle.kts` (2.1.20)
- **لم يُمَس** تعطيل `org.jetbrains.kotlin.android` plugin في `app/build.gradle.kts` بناءً على طلب صريح (الإعداد الحالي يعمل في بايبلاين GitHub Actions الموجود)

## 5) ملاحظة تقنية مهمة: Outline وBox-Shadow

`media_kit`'s `SubtitleViewConfiguration` لا يوفر سوى `TextStyle`/`TextAlign`/`padding` بلا وصول لشجرة widgets خاصة بالترجمة. لذلك:
- **Outline** يُحاكى بمجموعة 8 ظلال (`Shadow`) موزَّعة بزوايا حول النص بنفس سماكة الإزاحة المطلوبة (تقنية قياسية لمحاكاة Stroke في TextStyle).
- **Box Shadow** يُحاكى بظل أكبر امتداداً خلف النص، وليس صندوقاً منفصلاً حقيقياً (هذا المستوى من التحكم غير متاح في الإصدار الحالي من المكتبة).

هذا موثَّق في تعليقات `subtitle_style_builder.dart` لأي تطوير مستقبلي.
