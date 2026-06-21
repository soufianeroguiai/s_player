import 'package:flutter/services.dart';

class PipService {
  static const _channel = MethodChannel('com.splayer.app/pip');

  static Future<void> enter() async {
    try {
      await _channel.invokeMethod('enterPip');
    } catch (e) {}
  }
}