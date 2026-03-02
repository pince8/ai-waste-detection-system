import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/main_screen.dart';

List<CameraDescription>? cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🚀 === UYGULAMA BAŞLIYOR ===');
  
  try {
    cameras = await availableCameras();
    print('✅ Kamera bulundu: ${cameras!.length} adet');
  } catch (e) {
    print('❌ Kamera hatası: $e');
  }
  
  print('🎉 === UYGULAMA HAZIR ===');
  
  runApp(AtikTespitApp());
}

class AtikTespitApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atık Tespit',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: MainScreen(cameras: cameras!),
    );
  }
}