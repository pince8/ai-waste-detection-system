import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../utils/detector.dart';

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  File? _selectedImage;
  List<Detection> _results = [];
  bool _isProcessing = false;
  late Detector _detector;
  bool _isModelLoaded = false;
  
  @override
  void initState() {
    super.initState();
    _initDetector();
  }
  
  void _initDetector() async {
    _detector = Detector();
    await _detector.load();
    setState(() {
      _isModelLoaded = true;
    });
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _results = [];
      });
    }
  }
  
  Future<void> _processImage() async {
    if (_selectedImage == null || !_isModelLoaded) return;
    
    setState(() {
      _isProcessing = true;
      _results = [];
    });
    
    // YENİ FONKSİYON: detectFromImage
    final results = await _detector.detectFromImage(_selectedImage!);
    
    setState(() {
      _results = results;
      _isProcessing = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Resim Yükle & Analiz Et'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Görsel yükleme alanı (KUTUCUKLAR İLE)
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 2),
                borderRadius: BorderRadius.circular(15),
                color: Colors.grey[100],
              ),
              child: Stack(
                children: [
                  if (_selectedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    ),
                  
                  // KUTUCUKLAR (Resim üzerinde)
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
                  
                  if (_selectedImage == null)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, size: 60, color: Colors.grey),
                          SizedBox(height: 10),
                          Text('Görsel seçilmedi'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Butonlar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: Icon(Icons.photo_library),
                  label: Text('Galeriden Seç'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isProcessing || _selectedImage == null ? null : _processImage,
                  icon: Icon(Icons.search),
                  label: _isProcessing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : Text('Analiz Et'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 20),
            
            // Sonuçlar
            if (_results.isNotEmpty)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tespit Edilenler:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
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
          ],
        ),
      ),
    );
  }
}