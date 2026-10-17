import 'package:flutter_test/flutter_test.dart';
import 'package:medscan/data/models/chat_message.dart';
import 'package:medscan/data/models/chat_session.dart';

void main() {
  group('ChatSession Model & ChatGPT Grouping Tests', () {
    test('ChatSession serializes and deserializes correctly', () {
      final now = DateTime.now();
      final msg = ChatMessage(
        role: 'user',
        content: 'Puis-je prendre du paracétamol avec de l\'ibuprofène ?',
        timestamp: now,
      );
      final session = ChatSession(
        id: 'sess-123',
        title: 'Paracétamol et ibuprofène',
        mode: 'chat',
        createdAt: now,
        updatedAt: now,
        messages: [msg],
      );

      final jsonMap = session.toJson();
      expect(jsonMap['id'], 'sess-123');
      expect(jsonMap['title'], 'Paracétamol et ibuprofène');
      expect(jsonMap['mode'], 'chat');
      expect(jsonMap['messages'], isNotEmpty);

      final restored = ChatSession.fromJson(jsonMap);
      expect(restored.id, 'sess-123');
      expect(restored.title, 'Paracétamol et ibuprofène');
      expect(restored.messages.length, 1);
      expect(restored.messages.first.content, msg.content);
    });

    test('ChatSession copyWith updates properties properly', () {
      final now = DateTime.now();
      final session = ChatSession(
        id: 'sess-1',
        title: 'Initial Title',
        mode: 'chat',
        createdAt: now,
        updatedAt: now,
        messages: [],
      );

      final updated = session.copyWith(
        title: 'Updated Title',
        messages: [
          ChatMessage(role: 'user', content: 'Hello', timestamp: now),
        ],
      );

      expect(updated.id, 'sess-1');
      expect(updated.title, 'Updated Title');
      expect(updated.messages.length, 1);
    });
  });
}
