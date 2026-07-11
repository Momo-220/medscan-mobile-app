import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/di/providers.dart';
import '../../../data/models/scan_response.dart';
import '../../../data/models/recent_scan.dart';
import '../../../data/remote/api_client.dart';
import '../../home/providers/credits_provider.dart';
import '../../home/providers/health_stats_provider.dart';
import '../../home/providers/recent_scans_provider.dart';
import '../../history/providers/pharmacy_provider.dart';
import '../../../shared/utils/localization.dart';

class ScanState {
  final bool loading;
  final String? statusText; // text progress e.g. "Uploading...", "Analyzing..."
  final int progressPercent;
  final ScanResponse? result;
  final String? error;

  ScanState({
    this.loading = false,
    this.statusText,
    this.progressPercent = 0,
    this.result,
    this.error,
  });

  ScanState copyWith({
    bool? loading,
    String? statusText,
    int? progressPercent,
    ScanResponse? result,
    String? error,
  }) {
    return ScanState(
      loading: loading ?? this.loading,
      statusText: statusText ?? this.statusText,
      progressPercent: progressPercent ?? this.progressPercent,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

class ScanNotifier extends StateNotifier<ScanState> {
  final Ref _ref;

  ScanNotifier(this._ref) : super(ScanState());

  void reset() {
    state = ScanState();
  }

  String getLocalizedStatusText(String key, String langCode) {
    final Map<String, Map<String, String>> translations = {
      'upload': {
        'fr': 'Téléversement de la photo...',
        'en': 'Uploading photo...',
        'tr': 'Fotoğraf yükleniyor...',
        'ar': 'جاري رفع الصورة...',
      },
      'step0': {
        'fr': 'Analyse de l\'image...',
        'en': 'Analyzing image...',
        'tr': 'Görüntü analiz ediliyor...',
        'ar': 'جاري تحليل الصورة...',
      },
      'step1': {
        'fr': 'Détection du texte...',
        'en': 'Detecting text...',
        'tr': 'Metin algılanıyor...',
        'ar': 'جاري الكشف عن النص...',
      },
      'step2': {
        'fr': 'Identification du médicament...',
        'en': 'Identifying medication...',
        'tr': 'İlaç tanımlanıyor...',
        'ar': 'جاري تحديد الدواء...',
      },
      'step3': {
        'fr': 'Extraction des molécules...',
        'en': 'Extracting molecules...',
        'tr': 'Moleküller ayrıştırılıyor...',
        'ar': 'جاري استخراج الجزيئات...',
      },
      'step4': {
        'fr': 'Analyse de sécurité par l\'IA...',
        'en': 'AI safety analysis...',
        'tr': 'Yapay zeka güvenlik analizi...',
        'ar': 'تحليل السلامة بالذكاء الاصطناعي...',
      },
      'step5': {
        'fr': 'Génération de la fiche...',
        'en': 'Generating factsheet...',
        'tr': 'Rapor oluşturuluyor...',
        'ar': 'جاري إنشاء الملف...',
      },
    };

    final entry = translations[key];
    if (entry == null) return key;
    return entry[langCode.toLowerCase()] ?? entry['en'] ?? key;
  }

  Future<File> _compressAndResizeImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage == null) return file;

      // Resize image if it exceeds 1024 in any dimension
      img.Image resizedImage = decodedImage;
      const maxDimension = 1024;
      if (decodedImage.width > maxDimension || decodedImage.height > maxDimension) {
        if (decodedImage.width > decodedImage.height) {
          resizedImage = img.copyResize(decodedImage, width: maxDimension);
        } else {
          resizedImage = img.copyResize(decodedImage, height: maxDimension);
        }
      }

      // Compress to JPEG with 80% quality
      final compressedBytes = img.encodeJpg(resizedImage, quality: 80);
      
      // Save to a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);
      return tempFile;
    } catch (e) {
      debugPrint('Compression failed, uploading original: $e');
      return file;
    }
  }

  Future<ScanResponse?> uploadAndScan(File imageFile, String languageCode) async {
    state = ScanState(
      loading: true,
      statusText: getLocalizedStatusText('upload', languageCode),
      progressPercent: 10,
    );

    // Dynamic fake progress ticks to give premium breathing visual feel (matching React ScanningScreen)
    Timer? progressTimer;
    int currentProgress = 10;

    progressTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!state.loading) {
        timer.cancel();
        return;
      }
      
      if (currentProgress < 95) {
        currentProgress += 5 + (10 - currentProgress % 10) ~/ 3;
        if (currentProgress > 95) currentProgress = 95;
        
        // Pick status string based on progress bracket
        final stepIndex = (currentProgress / 15).floor().clamp(0, 5);
        final statusText = getLocalizedStatusText('step$stepIndex', languageCode);

        state = state.copyWith(
          progressPercent: currentProgress,
          statusText: statusText,
        );
      }
    });

    File? processedFile;
    try {
      final client = _ref.read(apiClientProvider);
      
      // Compress and resize image to speed up upload & backend processing
      processedFile = await _compressAndResizeImage(imageFile);
      
      // Setup multipart form data
      final fileName = processedFile.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          processedFile.path,
          filename: fileName,
        ),
      });

      // Execute request with increased timeout (60s)
      final response = await client.post(
        '/scan',
        data: formData,
        queryParameters: {'language': languageCode},
        options: Options(
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      progressTimer.cancel();

      // 1. Copy the file to local persistent documents directory
      String finalLocalImagePath = imageFile.path;
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final localImageDir = Directory('${appDir.path}/scanned_images');
        if (!localImageDir.existsSync()) {
          localImageDir.createSync(recursive: true);
        }
        final localFileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.path.split('/').last}';
        final localFile = await imageFile.copy('${localImageDir.path}/$localFileName');
        finalLocalImagePath = localFile.path;
      } catch (_) {}

      final scanResponseRaw = response.data;
      // Override imageUrl with local path
      scanResponseRaw['image_url'] = finalLocalImagePath;

      final scanResponse = ScanResponse.fromJson(scanResponseRaw);
      
      // 2. Save to local pharmacy history cache immediately (using phone local storage instead of MongoDB)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final prefs = _ref.read(sharedPrefsServiceProvider);
        final cacheJson = prefs.getPharmacyCache(user.uid);
        List<RecentScan> scansList = [];
        if (cacheJson != null) {
          try {
            final List<dynamic> decoded = json.decode(cacheJson);
            scansList = decoded.map((e) => RecentScan.fromJson(e)).toList();
          } catch (_) {}
        }
        
        final newScanItem = RecentScan(
          id: scanResponse.scanId.isNotEmpty ? scanResponse.scanId : DateTime.now().millisecondsSinceEpoch.toString(),
          scanId: scanResponse.scanId.isNotEmpty ? scanResponse.scanId : DateTime.now().millisecondsSinceEpoch.toString(),
          medicationName: scanResponse.medicationName,
          genericName: scanResponse.genericName,
          dosage: scanResponse.dosage,
          form: scanResponse.form,
          category: scanResponse.category,
          manufacturer: scanResponse.manufacturer,
          packagingLanguage: scanResponse.packagingLanguage,
          imageUrl: finalLocalImagePath,
          confidence: scanResponse.confidence,
          scannedAt: DateTime.now(),
          analysisData: scanResponse.toJson(), // save full scan response to JSON analysisData
          warnings: scanResponse.warnings,
          contraindications: scanResponse.contraindications != null ? [scanResponse.contraindications!] : [],
          interactions: scanResponse.interactions != null ? [scanResponse.interactions!] : [],
          sideEffects: scanResponse.sideEffects != null ? [scanResponse.sideEffects!] : [],
          disclaimer: scanResponse.disclaimer,
        );
        
        scansList.insert(0, newScanItem);
        if (scansList.length > 50) {
          scansList = scansList.sublist(0, 50);
        }
        
        final listJson = scansList.map((e) => e.toJson()).toList();
        await prefs.setPharmacyCache(user.uid, json.encode(listJson));
        final lang = _ref.read(languageProvider);
        await prefs.setPharmacyCacheLanguage(user.uid, lang);
      }

      state = state.copyWith(
        loading: false,
        progressPercent: 100,
        statusText: 'Analyse terminée avec succès !',
        result: scanResponse,
      );

      // Refresh relevant data providers immediately so the home metrics are updated
      _ref.read(creditsProvider.notifier).fetchCredits(quietly: true);
      _ref.read(healthStatsProvider.notifier).fetchStats(quietly: true);
      _ref.read(recentScansProvider.notifier).fetchRecentScans();
      
      // Refresh the pharmacy screen history list as well
      if (user != null) {
        try {
          _ref.read(pharmacyProvider.notifier).fetchPharmacyList(user.uid);
        } catch (_) {}
      }

      return scanResponse;
    } catch (e) {
      progressTimer.cancel();
      String errorMsg = e.toString();
      
      if (e is InsufficientCreditsException) {
        errorMsg = 'INSUFFICIENT_CREDITS';
      } else if (e is NetworkException) {
        errorMsg = e.message;
      } else if (e is ServerException) {
        errorMsg = e.message;
      } else {
        errorMsg = 'Une erreur est survenue lors de l\'analyse de l\'image.';
      }

      state = state.copyWith(
        loading: false,
        error: errorMsg,
      );
      
      rethrow;
    } finally {
      if (processedFile != null && processedFile.path != imageFile.path) {
        try {
          await processedFile.delete();
        } catch (_) {}
      }
    }
  }
}

final scanProvider = StateNotifierProvider<ScanNotifier, ScanState>((ref) {
  return ScanNotifier(ref);
});

