import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

class Detection {
  final Rect box;
  final String label;
  final double confidence;
  final bool isRecyclable;

  Detection({
    required this.box,
    required this.label,
    required this.confidence,
    required this.isRecyclable,
  });
}

class Detector {
  Interpreter? _interpreter;
  bool _isLoaded = false;
  
  final List<String> _labels = [
    'Cardboard-Recyclable',    // 0
    'Glass-Recyclable',        // 1
    'Metal-Recyclable',        // 2
    'Paper-Recyclable',        // 3
    'Plastic-Recyclable',      // 4
    'Organic-Non-Recyclable'   // 5
  ];

  /// 🔹 MODEL YÜKLE
  Future<void> load() async {
    print('📦 GERÇEK MODEL YÜKLENİYOR...');
    
    try {
      // 1. Model dosyasını asset'ten yükle
      final modelData = await rootBundle.load('assets/model.tflite');
      final modelBytes = modelData.buffer.asUint8List();
      
      // 2. Interpreter oluştur
      _interpreter = await Interpreter.fromBuffer(modelBytes);
      
      // 3. Model bilgilerini yazdır
      final input = _interpreter!.getInputTensor(0);
      final output = _interpreter!.getOutputTensor(0);
      
      print('✅✅✅ MODEL GERÇEKTEN YÜKLENDİ!');
      print('📥 Input: ${input.shape} (${input.type})');
      print('📤 Output: ${output.shape} (${output.type})');
      
      _isLoaded = true;
      
    } catch (e) {
      print('❌❌❌ MODEL YÜKLEME HATASI: $e');
      _isLoaded = false;
      throw Exception('Model yüklenemedi: $e');
    }
  }

  /// 🔹 GERÇEK KAMERA TESPİTİ
  Future<List<Detection>> detectFromCamera(List<int>? imageBytes) async {
    print('🎯 GERÇEK KAMERA TESPİTİ BAŞLIYOR...');
    
    if (!_isLoaded || _interpreter == null) {
      print('❌ Model yüklenmemiş!');
      return _getRealDetections();
    }
    
    if (imageBytes == null || imageBytes.isEmpty) {
      print('⚠️ Kamera görüntüsü yok, test input kullanılıyor');
      return _testModelWithRealData();
    }
    
    try {
      print('🖼️ Gerçek kamera görüntüsü işleniyor: ${imageBytes.length} bytes');
      
      // 1. Görüntüyü modele uygun hale getir
      final input = _prepareImageForModel(imageBytes);
      
      // 2. Modeli çalıştır
      final output = _runRealModel(input);
      
      // 3. Model çıktısını işle
      final results = _processRealModelOutput(output);
      
      print('✅✅✅ GERÇEK MODEL TESPİT ETTİ: ${results.length} nesne');
      return results;
      
    } catch (e) {
      print('❌ Gerçek tespit hatası: $e');
      return _getRealDetections();
    }
  }

  /// 🔹 GERÇEK RESİM TESPİTİ
  Future<List<Detection>> detectFromImage(File imageFile) async {
    print('🖼️ GERÇEK RESİM TESPİTİ BAŞLIYOR...');
    
    if (!_isLoaded) {
      return _getRealDetections();
    }
    
    try {
      // 1. Resim dosyasını oku
      final imageBytes = await imageFile.readAsBytes();
      print('📊 Resim boyutu: ${imageBytes.length} bytes');
      
      // 2. Görüntüyü modele uygun hale getir
      final input = _prepareImageForModel(imageBytes);
      
      // 3. Modeli çalıştır
      final output = _runRealModel(input);
      
      // 4. Model çıktısını işle
      final results = _processRealModelOutput(output);
      
      return results;
      
    } catch (e) {
      print('❌ Resim tespit hatası: $e');
      return _getRealDetections();
    }
  }

  /// 🔹 GÖRÜNTÜYÜ MODELE HAZIRLA (IMAGE PACKAGE İLE)
  Float32List _prepareImageForModel(List<int> imageBytes) {
    print('🔧 Görüntü preprocessing başlıyor... (${imageBytes.length} bytes)');
    
    try {
      // 1. JPEG/PNG'yi decode et
      final image = img.decodeImage(Uint8List.fromList(imageBytes));
      
      if (image == null) {
        print('❌ Görüntü decode edilemedi!');
        throw Exception('Image decode failed');
      }
      
      print('📐 Orijinal boyut: ${image.width}x${image.height}');
      
      // 2. 640x640'a resize et (aspect ratio korumalı)
      final targetSize = 640;
      
      // Aspect ratio hesapla
      final scaleX = targetSize / image.width;
      final scaleY = targetSize / image.height;
      final scale = scaleX < scaleY ? scaleX : scaleY;
      
      final scaledWidth = (image.width * scale).round();
      final scaledHeight = (image.height * scale).round();
      
      print('📐 Scaled boyut: ${scaledWidth}x${scaledHeight}');
      
      // Resize yap
      final resized = img.copyResize(
        image,
        width: scaledWidth,
        height: scaledHeight,
        interpolation: img.Interpolation.linear,
      );
      
      // 3. Padding ekle (640x640 yap)
      final offsetX = (targetSize - scaledWidth) ~/ 2;
      final offsetY = (targetSize - scaledHeight) ~/ 2;
      
      print('📐 Padding: offsetX=$offsetX, offsetY=$offsetY');
      
      // Gri arka plan ile 640x640 canvas oluştur
      final canvas = img.Image(width: targetSize, height: targetSize);
      img.fill(canvas, color: img.ColorRgb8(128, 128, 128)); // Gri
      
      // Resmi ortaya yerleştir
      img.compositeImage(canvas, resized, dstX: offsetX, dstY: offsetY);
      
      // 4. Float32List'e çevir ve normalize et (0-1)
      // DENEME 4: BGR Formatı + 0-1 Normalizasyon
      // YOLO modelleri genelde OpenCV (BGR) ile eğitilir.
      
      final input = Float32List(targetSize * targetSize * 3);
      
      int idx = 0;
      for (int y = 0; y < targetSize; y++) {
        for (int x = 0; x < targetSize; x++) {
          final pixel = canvas.getPixel(x, y);
          
          // BGR sırası ile ve 0-1 normalize
          input[idx++] = pixel.b / 255.0; // Blue
          input[idx++] = pixel.g / 255.0; // Green
          input[idx++] = pixel.r / 255.0; // Red
        }
      }
      
      print('✅ Görüntü hazırlandı: ${targetSize}x${targetSize}x3 (BGR, 0-1 Range)');
      
      // İlk birkaç pixel'i kontrol et
      print('📊 İlk pixel BGR: [${input[0].toStringAsFixed(3)}, ${input[1].toStringAsFixed(3)}, ${input[2].toStringAsFixed(3)}]');
      
      // Ortalama değerleri kontrol et
      double avgB = 0, avgG = 0, avgR = 0;
      for (int i = 0; i < input.length; i += 3) {
        avgB += input[i];
        avgG += input[i + 1];
        avgR += input[i + 2];
      }
      final numPixels = input.length ~/ 3;
      avgB /= numPixels;
      avgG /= numPixels;
      avgR /= numPixels;
      
      print('📊 Ortalama BGR: [${avgB.toStringAsFixed(3)}, ${avgG.toStringAsFixed(3)}, ${avgR.toStringAsFixed(3)}]');
      
      if (avgB < 0.01 && avgG < 0.01 && avgR < 0.01) {
        print('⚠️⚠️⚠️ UYARI: Görüntü tamamen siyah! Input yanlış olabilir.');
      } else if (avgB > 0.99 && avgG > 0.99 && avgR > 0.99) {
        print('⚠️⚠️⚠️ UYARI: Görüntü tamamen beyaz! Input yanlış olabilir.');
      }
      
      return input;
      
    } catch (e, stackTrace) {
      print('❌ Preprocessing hatası: $e');
      print('Stack trace: $stackTrace');
      throw e;
    }
  }

  /// 🔹 GERÇEK MODEL ÇALIŞTIR
  List<dynamic> _runRealModel(Float32List input) {
    final outputShape = _interpreter!.getOutputTensor(0).shape;
    final outputSize = outputShape.reduce((a, b) => a * b);
    final output = List.filled(outputSize, 0.0).reshape(outputShape);
    
    print('⚡ GERÇEK MODEL ÇALIŞTIRILIYOR...');
    final stopwatch = Stopwatch()..start();
    
    _interpreter!.run(input.reshape([1, 640, 640, 3]), output);
    
    stopwatch.stop();
    print('✅ Model ${stopwatch.elapsedMilliseconds}ms içinde çalıştı');
    
    return output;
  }

  /// 🔹 GERÇEK MODEL ÇIKTISINI İŞLE (ULTRA DEBUG MODE)
  List<Detection> _processRealModelOutput(List<dynamic> output) {
    print('🔬🔬🔬 GERÇEK MODEL ÇIKTISI İŞLENİYOR (ULTRA DEBUG)...');
    
    final results = <Detection>[];
    
    try {
      // LEVEL 1: Output ana yapısı
      print('═══════════════════════════════════════');
      print('📊 LEVEL 1: Output Ana Yapısı');
      print('   Type: ${output.runtimeType}');
      print('   Length: ${output.length}');
      print('   Is List: ${output is List}');
      
      if (output.isEmpty) {
        print('❌ Output boş!');
        return _getRealDetections();
      }
      
      // LEVEL 2: Output[0] yapısı
      print('═══════════════════════════════════════');
      print('📊 LEVEL 2: Output[0] Yapısı');
      final outputData = output[0];
      print('   Type: ${outputData.runtimeType}');
      print('   Is List: ${outputData is List}');
      
      if (outputData is! List) {
        print('❌ Output[0] bir liste değil!');
        // Belki flat array? İlk 20 değeri yazdır
        if (outputData is List) {
          final flatList = outputData as List;
          print('   Flat array length: ${flatList.length}');
          print('   İlk 20 değer: ${flatList.take(20).toList()}');
        }
        return _getRealDetections();
      }
      
      final dataList = outputData as List;
      print('   Length: ${dataList.length}');
      
      if (dataList.isEmpty) {
        print('❌ Output[0] boş!');
        return _getRealDetections();
      }
      
      // LEVEL 3: Output[0][0] yapısı
      print('═══════════════════════════════════════');
      print('📊 LEVEL 3: Output[0][0] Yapısı');
      print('   Type: ${dataList[0].runtimeType}');
      print('   Is List: ${dataList[0] is List}');
      print('   Is num: ${dataList[0] is num}');
      
      // Eğer output[0][0] bir sayı ise, flat array formatı
      if (dataList[0] is num) {
        print('⚠️ FLAT ARRAY FORMAT TESPİT EDİLDİ!');
        print('   Total values: ${dataList.length}');
        print('   İlk 30 değer: ${dataList.take(30).map((e) => (e as num).toDouble().toStringAsFixed(3)).toList()}');
        
        // YOLO v8 flat format: [x1,y1,w1,h1,c1,p1_1,p1_2,...,x2,y2,w2,h2,c2,p2_1,p2_2,...]
        // veya transpose: tüm x'ler, tüm y'ler, tüm w'ler, tüm h'ler, tüm c'ler, tüm p'ler
        
        print('❌ Flat array formatı henüz desteklenmiyor!');
        return _getRealDetections();
      }
      
      // Eğer output[0][0] bir liste ise, 2D array formatı
      if (dataList[0] is! List) {
        print('❌ Output[0][0] ne liste ne de sayı!');
        return _getRealDetections();
      }
      
      final firstRow = dataList[0] as List;
      print('   First row length: ${firstRow.length}');
      print('   İlk 10 değer: ${firstRow.take(10).map((e) => (e as num).toDouble().toStringAsFixed(3)).toList()}');
      
      // LEVEL 4: Format tespiti
      print('═══════════════════════════════════════');
      print('📊 LEVEL 4: Format Tespiti');
      print('   Shape: [${dataList.length}, ${firstRow.length}]');
      
      bool isTransposed = false;
      int numFeatures = 0;
      int numCells = 0;
      
      // [10, 8400] formatı (features x cells)
      if (dataList.length <= 20 && firstRow.length > 100) {
        numFeatures = dataList.length;
        numCells = firstRow.length;
        isTransposed = false;
        print('   ✅ Format: [${numFeatures}, ${numCells}] - Standard YOLO (features x cells)');
      }
      // [8400, 10] formatı (cells x features)
      else if (dataList.length > 100 && firstRow.length <= 20) {
        numCells = dataList.length;
        numFeatures = firstRow.length;
        isTransposed = true;
        print('   ✅ Format: [${numCells}, ${numFeatures}] - Transposed YOLO (cells x features)');
      }
      else {
        print('   ❌ Beklenmeyen format: [${dataList.length}, ${firstRow.length}]');
        print('   Muhtemelen custom format. İlk 5 satırı yazdıralım:');
        for (int i = 0; i < 5 && i < dataList.length; i++) {
          if (dataList[i] is List) {
            final row = dataList[i] as List;
            print('   Row $i: ${row.take(10).map((e) => (e as num).toDouble().toStringAsFixed(3)).toList()}');
          }
        }
        return _getRealDetections();
      }
      
      // LEVEL 5: Feature analizi
      print('═══════════════════════════════════════');
      print('📊 LEVEL 5: Feature Analizi');
      print('   Num Features: ${numFeatures}');
      print('   Num Cells: ${numCells}');
      
      if (numFeatures < 5) {
        print('   ❌ Yetersiz feature (minimum 5 gerekli: x,y,w,h,conf)');
        return _getRealDetections();
      }
      
      final numClasses = numFeatures - 4; // YOLOv8: 4 bbox + Classes
      
      // IOU Threshold (Çakışmaları temizlemek için)
      final iouThreshold = 0.60;
      
      print('📊 Feature Analizi (YOLOv8 Modu):');
      print('   Num Classes: ${numClasses}');
      print('   Expected: 4 bbox + ${numClasses} class probabilities');
      
      // İlk 3 hücrenin tüm değerlerini yazdır
      print('═══════════════════════════════════════');
      print('📊 LEVEL 6: İlk 3 Hücre Detayları');
      for (int i = 0; i < 3 && i < numCells; i++) {
        List<double> cellData = [];
        
        if (isTransposed) {
          final cell = dataList[i] as List;
          cellData = cell.map((e) => (e as num).toDouble()).toList();
        } else {
          for (int f = 0; f < numFeatures; f++) {
            cellData.add((dataList[f][i] as num).toDouble());
          }
        }
        
        print('   Hücre $i:');
        print('      x=${cellData[0].toStringAsFixed(4)}, y=${cellData[1].toStringAsFixed(4)}, w=${cellData[2].toStringAsFixed(4)}, h=${cellData[3].toStringAsFixed(4)}');
        // YOLOv8'de objectness skoru yok, direkt class skorları var
        if (cellData.length > 4) {
          print('      classes=${cellData.sublist(4).map((e) => e.toStringAsFixed(4)).toList()}');
        }
      }
      
      // LEVEL 7: Tespit arama (YÜKSEK THRESHOLD - Çöplüğü önle)
      print('═══════════════════════════════════════');
      
      final confThreshold = 0.45; // Sadece %45 ve üzeri güvenli olanları göster
      print('📊 LEVEL 7: Tespit Arama (threshold=$confThreshold)');
      
      int validDetections = 0;
      
      for (int i = 0; i < numCells; i++) {
        // 1. Class Score'larını topla ve max bul
        double maxClassScore = 0.0;
        int maxClassIndex = -1;
        
        // Feature 4'ten başla (0-3 bbox)
        for (int c = 0; c < numClasses; c++) {
          double score = 0.0;
          if (isTransposed) {
            // [cells][features] -> outputData[i][4+c]
            score = (dataList[i][4 + c] as num).toDouble();
          } else {
            // [features][cells] -> dataList[4+c][i]
            score = (dataList[4 + c][i] as num).toDouble();
          }
          
          if (score > maxClassScore) {
            maxClassScore = score;
            maxClassIndex = c;
          }
        }
        
        // 2. Threshold kontrolü
        // YOLOv8'de objectness yoktur, direkt class score kullanılır
        if (maxClassScore < confThreshold) continue;
        
        // 3. BBox koordinatlarını al
        double x, y, w, h;
        if (isTransposed) {
          x = (dataList[i][0] as num).toDouble();
          y = (dataList[i][1] as num).toDouble();
          w = (dataList[i][2] as num).toDouble();
          h = (dataList[i][3] as num).toDouble();
        } else {
          x = (dataList[0][i] as num).toDouble();
          y = (dataList[1][i] as num).toDouble();
          w = (dataList[2][i] as num).toDouble();
          h = (dataList[3][i] as num).toDouble();
        }
        
        // 4. Koordinatları düzelt (cx,cy,w,h -> x1,y1,x2,y2)
        // Koordinatlar normalize edilmiş (0-1) mi yoksa pixel mi?
        // Genellikle normalize edilmiş gelir ama debug çıktısına göre çok küçük (0.02).
        // Bu yüzden normalizasyon doğru.
        
        // Model çıktısı 0-1 aralığında normalize edilmiş koordinatlar veriyor.
        // Bu koordinatları 640x640 input boyutuna ölçekleyelim.
        final double scaledX = x * 640;
        final double scaledY = y * 640;
        final double scaledW = w * 640;
        final double scaledH = h * 640;

        final rect = Rect.fromCenter(
          center: Offset(scaledX, scaledY),
          width: scaledW,
          height: scaledH,
        );
        
        // Sınıf etiketini bul
        String label = 'Unknown';
        if (maxClassIndex != -1 && maxClassIndex < _labels.length) {
          label = _labels[maxClassIndex];
        } else {
          label = 'Class $maxClassIndex';
        }
        
        bool isRecyclable = label.toLowerCase().contains('recyclable');
        
        results.add(Detection(
          box: rect,
          label: label,
          confidence: maxClassScore, // Confidence artık direkt max class score
          isRecyclable: isRecyclable,
        ));
        
        // Debug için sadece ilk birkaç tanesini detaylı yaz
        if (validDetections < 3) {
           print('   🔍 Bulundu: Class=$maxClassIndex ($label), Conf=${maxClassScore.toStringAsFixed(4)}');
           print('      Box: $rect');
        }
        validDetections++;
      }
      
      print('═══════════════════════════════════════');
      print('📦 HAM TESPİT SAYISI: ${results.length}');
      
      if (results.isEmpty) {
        print('⚠️⚠️⚠️ HİÇ TESPİT BULUNAMADI!');
        print('Model çalıştı ama hiçbir nesne tespit edemedi.');
        print('Bu NORMAL olabilir - kamera önünde tespit edilebilir nesne yok.');
        print('Fallback tespitler gösteriliyor...');
        return _getRealDetections();
      }
      
      // NMS uygula
      final filteredResults = _applyNMS(results, iouThreshold: 0.4);
      print('📦 NMS SONRASI: ${filteredResults.length} tespit');
      print('═══════════════════════════════════════');
      
      return filteredResults;
      
    } catch (e, stackTrace) {
      print('❌❌❌ HATA: $e');
      print('Stack trace:');
      print(stackTrace);
      return _getRealDetections();
    }
  }
  
  /// 🔹 NMS (Non-Maximum Suppression) - Çakışan kutuları temizle
  List<Detection> _applyNMS(List<Detection> detections, {double iouThreshold = 0.4}) {
    if (detections.isEmpty) return [];
    
    // Confidence'a göre sırala (yüksekten düşüğe)
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    final selected = <Detection>[];
    final suppressed = <bool>[];
    
    for (int i = 0; i < detections.length; i++) {
      suppressed.add(false);
    }
    
    for (int i = 0; i < detections.length; i++) {
      if (suppressed[i]) continue;
      
      selected.add(detections[i]);
      
      // Bu kutu ile çakışan diğer kutuları bastır
      for (int j = i + 1; j < detections.length; j++) {
        if (suppressed[j]) continue;
        
        final iou = _calculateIoU(detections[i].box, detections[j].box);
        if (iou > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    
    print('📦 NMS: ${detections.length} -> ${selected.length} tespit');
    return selected;
  }
  
  /// 🔹 IoU (Intersection over Union) hesapla
  double _calculateIoU(Rect box1, Rect box2) {
    final intersection = box1.intersect(box2);
    if (intersection.isEmpty) return 0.0;
    
    final intersectionArea = intersection.width * intersection.height;
    final box1Area = box1.width * box1.height;
    final box2Area = box2.width * box2.height;
    final unionArea = box1Area + box2Area - intersectionArea;
    
    return intersectionArea / unionArea;
  }

  /// 🔹 MODELİ GERÇEK VERİ İLE TEST ET
  List<Detection> _testModelWithRealData() {
    print('🧪 MODEL GERÇEK VERİ İLE TEST EDİLİYOR...');
    
    try {
      // Test görüntüsü oluştur (siyah-beyaz pattern)
      final testInput = Float32List(640 * 640 * 3);
      for (int i = 0; i < testInput.length; i++) {
        // Checkerboard pattern
        final x = (i ~/ 3) % 640;
        final y = (i ~/ 3) ~/ 640;
        testInput[i] = ((x ~/ 32) + (y ~/ 32)) % 2 == 0 ? 1.0 : 0.0;
      }
      
      // Modeli çalıştır
      final output = _runRealModel(testInput);
      
      // Çıktıyı işle
      final results = _processRealModelOutput(output);
      
      if (results.isNotEmpty) {
        print('✅✅✅ TEST BAŞARILI! Model gerçekten çalışıyor!');
      }
      
      return results;
      
    } catch (e) {
      print('❌ Test hatası: $e');
      return _getRealDetections();
    }
  }

  /// 🔹 GERÇEK TESPİTLER (fallback)
  List<Detection> _getRealDetections() {
    print('⚠️ Model çıktısı alınamadı, boş liste döndürülüyor.');
    // Artık sahte veri döndürmüyoruz, sadece boş liste
    return [];
  }

  /// 🔹 Mock KAPALI
  Future<List<Detection>> detectMock() async {
    print('❌ Mock KAPALI!');
    return [];
  }

  bool get isLoaded => _isLoaded;
  List<String> get labels => _labels;
}