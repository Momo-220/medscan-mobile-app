import 'package:flutter_test/flutter_test.dart';
import 'package:medscan/core/services/speech_recognition_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechRecognitionService Tests', () {
    late SpeechRecognitionService service;

    setUp(() {
      service = SpeechRecognitionService(
        silenceDuration: const Duration(milliseconds: 100),
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('Initial state is idle, transcript empty, default silence duration is 10s', () {
      final defaultService = SpeechRecognitionService();
      expect(defaultService.silenceDuration, equals(const Duration(seconds: 10)));
      defaultService.dispose();

      expect(service.state, equals(SpeechState.idle));
      expect(service.transcript, isEmpty);
      expect(service.soundLevel, equals(0.0));
      expect(service.errorMessage, isNull);
    });

    test('confirmFinish transitions state to processing and returns transcript', () async {
      service.transcriptNotifier.value = 'J\'ai un mal de tête persistant';
      final text = await service.confirmFinish();
      expect(text, equals('J\'ai un mal de tête persistant'));
      expect(service.state, equals(SpeechState.processing));
    });

    test('manualFinish acts identically to confirmFinish', () async {
      service.transcriptNotifier.value = 'Douleur au ventre';
      final text = await service.manualFinish();
      expect(text, equals('Douleur au ventre'));
      expect(service.state, equals(SpeechState.processing));
    });

    test('cancel resets transcript, sound level and returns to idle', () async {
      service.transcriptNotifier.value = 'Texte avant annulation';
      service.soundLevelNotifier.value = 0.8;
      await service.cancel();
      expect(service.transcript, isEmpty);
      expect(service.soundLevel, equals(0.0));
      expect(service.state, equals(SpeechState.idle));
    });
  });
}
