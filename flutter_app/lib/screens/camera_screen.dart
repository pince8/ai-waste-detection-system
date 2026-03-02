import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import 'dart:typed_data';
import '../utils/detector.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  
  CameraScreen({required this.cameras});
  
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Detector _detector;
  bool _isDetecting = false;
  List<Detection> _results = [];
  bool _isModelLoaded = false;
  bool _isCameraReady = false;
  bool _isRealtimeDetection = false;
  DateTime _lastProcessTime = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _initDetector();
    _initCamera();
  }
  
  void _initCamera() async {
    try {
      _controller = CameraController(
        widget.cameras.first,
        ResolutionPreset.medium,
      );
      
      await _controller.initialize();
      
      // KAMERA STREAM'İ BAŞLATMA - DEVRE DIŞI (DEBUG İÇİN)
      // Canlı tespit çok fazla log üretiyor, konsolu okuyamıyoruz
      // Sadece manuel tespit kullanacağız
      
      /* DEVRE DIŞI
      _controller.startImageStream((CameraImage cameraImage) {
        if (_isRealtimeDetection && _isModelLoaded && !_isDetecting) {
          // Frame throttling: 500ms'de bir işle
          final now = DateTime.now();
          if (now.difference(_lastProcessTime).inMilliseconds > 500) {
            _lastProcessTime = now;
            _processCameraFrame(cameraImage);
          }
        }
      });
      */
      
      setState(() {
        _isCameraReady = true;
      });
      
      print('📸 Kamera hazır (Stream KAPALI - sadece manuel tespit)');
      
    } catch (e) {
      print('❌ Kamera hatası: $e');
    }
  }
  
  void _initDetector() async {
    _detector = Detector();
    await _detector.load();
    setState(() {
      _isModelLoaded = true;
    });
    print('✅ Detector hazır');
  }
  
  /// 🔹 KAMERA FRAME'İNİ İŞLE
  void _processCameraFrame(CameraImage cameraImage) async {
    if (_isDetecting) return;
    
    setState(() {
      _isDetecting = true;
    });
    
    try {
      print('🎬 Frame işleniyor: ${cameraImage.width}x${cameraImage.height}');
      
      // CameraImage'den RGBA byte array oluştur
      final imageBytes = _convertCameraImageToRGBA(cameraImage);
      
      if (imageBytes.isNotEmpty) {
        print('📦 RGBA bytes hazır: ${imageBytes.length} bytes');
        
        // GERÇEK GÖRÜNTÜYÜ MODELE GÖNDER
        final results = await _detector.detectFromCamera(imageBytes);
        
        if (mounted) {
          setState(() {
            _results = results;
          });
        }
        
        print('🔄 Canlı tespit: ${results.length} nesne');
      }
    } catch (e) {
      print('❌ Frame işleme hatası: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDetecting = false;
        });
      }
    }
  }
  
  /// 🔹 CameraImage -> RGBA Uint8List dönüşümü (YUV420 -> RGB)
  Uint8List _convertCameraImageToRGBA(CameraImage cameraImage) {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;
      
      // YUV420 formatından RGB'ye dönüştür
      final int uvRowStride = cameraImage.planes[1].bytesPerRow;
      final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;
      
      final image = Uint8List(width * height * 4); // RGBA
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
          final int index = y * width + x;
          
          final yp = cameraImage.planes[0].bytes[index];
          final up = cameraImage.planes[1].bytes[uvIndex];
          final vp = cameraImage.planes[2].bytes[uvIndex];
          
          // YUV -> RGB conversion
          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
          
          // RGBA formatında kaydet
          image[index * 4] = r;
          image[index * 4 + 1] = g;
          image[index * 4 + 2] = b;
          image[index * 4 + 3] = 255; // Alpha
        }
      }
      
      print('✅ YUV420 -> RGBA dönüşümü tamamlandı');
      return image;
      
    } catch (e) {
      print('❌ Image convert hatası: $e');
      return Uint8List(0);
    }
  }
  
  /// 🔹 MANUEL TESPİT (RESİM ÇEK VE ANALİZ ET)
  Future<void> _takePictureAndDetect() async {
    print('🎯🎯🎯 MANUEL TESPİT BAŞLIYOR (RESİM ÇEK)');
    print('═══════════════════════════════════════');
    
    if (!_isModelLoaded || !_isCameraReady || _isDetecting) {
      print('⚠️ Hazır değil: model=${_isModelLoaded}, camera=${_isCameraReady}, detecting=${_isDetecting}');
      return;
    }
    
    setState(() {
      _isDetecting = true;
      _results = [];
    });
    
    try {
      print('📸 Resim çekiliyor...');
      
      // Resim çek
      final image = await _controller.takePicture();
      final file = File(image.path);
      
      print('✅ Resim çekildi: ${image.path}');
      print('📊 Dosya boyutu: ${await file.length()} bytes');
      
      // GERÇEK RESİM DOSYASINI MODELE GÖNDER
      print('🔄 Model çalıştırılıyor...');
      final results = await _detector.detectFromImage(file);
      
      setState(() {
        _results = results;
      });
      
      print('═══════════════════════════════════════');
      print('✅✅✅ MANUEL TESPİT TAMAMLANDI: ${results.length} nesne');
      print('═══════════════════════════════════════');
      
    } catch (e, stackTrace) {
      print('❌ Manuel tespit hatası: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _results = [];
      });
    } finally {
      setState(() {
        _isDetecting = false;
      });
    }
  }
  
  /// 🔹 RESİM ÇEK VE TESPİT ET
  Future<void> _takePicture() async {
    if (!_isCameraReady || _isDetecting) return;
    
    try {
      final image = await _controller.takePicture();
      final file = File(image.path);
      
      setState(() {
        _isDetecting = true;
        _results = [];
      });
      
      // GERÇEK RESİM DOSYASINI MODELE GÖNDER
      final results = await _detector.detectFromImage(file);
      
      setState(() {
        _results = results;
        _isDetecting = false;
      });
      
      print('✅ Resim analiz edildi: ${results.length} nesne');
      
    } catch (e) {
      print('❌ Resim çekme hatası: $e');
      setState(() {
        _isDetecting = false;
      });
    }
  }
  
  /// 🔹 CANLI TESPİT
  void _toggleRealtimeDetection() {
    setState(() {
      _isRealtimeDetection = !_isRealtimeDetection;
      if (!_isRealtimeDetection) {
        _results = [];
      }
    });
    
    print(_isRealtimeDetection ? '🔴 CANLI TESPİT BAŞLADI' : '🟢 CANLI TESPİT DURDU');
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _isRealtimeDetection = false;
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (_isCameraReady)
            CameraPreview(_controller)
          else
            Center(child: CircularProgressIndicator()),
          
          // KUTUCUKLAR
          ..._results.map((result) {
            return Positioned.fromRect(
              rect: result.box,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: result.isRecyclable ? Colors.green : Colors.red,
                    width: 3,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    color: result.isRecyclable ? Colors.green : Colors.red,
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      '${result.label.split('-')[0]} %${(result.confidence * 100).toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
          
          // CANLI TESPİT BUTONU
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(
                  _isRealtimeDetection ? Icons.stop : Icons.play_arrow,
                  color: _isRealtimeDetection ? Colors.red : Colors.green,
                  size: 30,
                ),
                onPressed: _toggleRealtimeDetection,
                tooltip: _isRealtimeDetection ? 'Durdur' : 'Canlı Tespit',
              ),
            ),
          ),
          
          // BUTONLAR
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // RESİM ÇEK BUTONU
                FloatingActionButton(
                  onPressed: _takePicture,
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.camera, size: 30),
                ),
                
                // TESPİT BUTONU
                FloatingActionButton(
                  onPressed: _takePictureAndDetect,
                  backgroundColor: _isDetecting ? Colors.blue : Colors.green,
                  child: _isDetecting
                      ? CircularProgressIndicator(color: Colors.white)
                      : Icon(Icons.search, size: 30),
                ),
              ],
            ),
          ),
          
          // SONUÇLAR
          if (_results.isNotEmpty)
            Positioned(
              top: 50,
              left: 20,
              right: 100,
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Tespit Edilenler:',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 10),
                        if (_isRealtimeDetection)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'CANLI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 10),
                    ..._results.map((result) {
                      return ListTile(
                        leading: Icon(
                          result.isRecyclable ? Icons.recycling : Icons.delete,
                          color: result.isRecyclable ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          result.label.split('-')[0],
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          '%${(result.confidence * 100).toStringAsFixed(1)} güven',
                          style: TextStyle(color: Colors.white70),
                        ),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: result.isRecyclable ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            result.isRecyclable ? 'DÖNÜŞÜR' : 'ATIK',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}