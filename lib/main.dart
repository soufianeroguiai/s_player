import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'theme/app_theme.dart';
import 'providers/settings_provider.dart';
import 'providers/library_provider.dart';
import 'app/permission_gate.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) => FlutterError.presentError(details);
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('❌ خطأ غير معالج: $error');
    runApp(ErrorApp(error.toString()));
    return true;
  };

  try {
    MediaKit.ensureInitialized();
  } catch (e) {
    runApp(ErrorApp('فشل تهيئة MediaKit:\n$e'));
    return;
  }

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  SettingsProvider settings;
  try {
    settings = SettingsProvider();
    await settings.load();
  } catch (e) {
    runApp(ErrorApp('فشل تحميل الإعدادات:\n$e'));
    return;
  }

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider(create: (_) => LibraryProvider()),
    ],
    child: const SPlayerApp(),
  ));
}

class SPlayerApp extends StatelessWidget {
  const SPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return MaterialApp(
      title: 'SR Player',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      home: const PermissionGate(child: HomeScreen()),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              const Text('عذراً، حدث خطأ',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Text(message,
                  style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                  textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => main(),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
