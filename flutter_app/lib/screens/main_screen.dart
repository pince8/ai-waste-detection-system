import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'camera_screen.dart';
import 'upload_screen.dart';

class MainScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  MainScreen({required this.cameras});
  
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [];
  
  @override
  void initState() {
    super.initState();
    _screens.add(CameraScreen(cameras: widget.cameras));
    _screens.add(UploadScreen());
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Atık Tespit Sistemi'),
        centerTitle: true,
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera),
            label: 'Kamera',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload),
            label: 'Yükle',
          ),
        ],
      ),
    );
  }
}