import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// شاشة تطلب الصلاحيات الضرورية (الوصول لمكتبة الفيديوهات) قبل
/// الدخول للتطبيق.
class PermissionGate extends StatefulWidget {
  final Widget child;
  const PermissionGate({super.key, required this.child});

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _checking = true;
  bool _allGranted = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    setState(() => _checking = true);

    final mediaStatus = await Permission.videos.request();
    final storageStatus = await Permission.storage.request();

    setState(() {
      _allGranted = mediaStatus.isGranted || storageStatus.isGranted;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text('جاري طلب الصلاحيات...', style: TextStyle(color: Colors.white70, fontSize: 16)),
          ]),
        ),
      );
    }

    if (!_allGranted) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.folder_off_rounded, color: Colors.white38, size: 80),
              const SizedBox(height: 24),
              const Text(
                'الصلاحيات مطلوبة',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'يحتاج التطبيق إلى إذن الوصول إلى الوسائط لعرض الفيديوهات.',
                style: TextStyle(color: Colors.white60, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Icons.security_rounded),
                label: const Text('منح الصلاحيات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _allGranted = true),
                child: const Text('تخطي', style: TextStyle(color: Colors.white38)),
              ),
            ]),
          ),
        ),
      );
    }

    return widget.child;
  }
}
