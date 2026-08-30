import 'package:flutter_test/flutter_test.dart';
import 'package:plant_project/services/voice_assistant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceAssistantService Tests', () {
    final service = VoiceAssistantService.instance;

    test('Initial State verification', () {
      expect(service.isListening.value, isFalse);
      expect(service.recognizedText.value, isEmpty);
      expect(service.currentlySpeakingId.value, isNull);
    });

    test(
      'sanitizeForSpeech cleans markdown bold, headers, and code blocks',
      () {
        const input = """### Crop Diagnostics
**Tomato Blight** is caused by `Phytophthora infestans`.
- Apply copper fungicide.
```dart
void test() {}
```""";

        final sanitized = service.sanitizeForSpeech(input);

        expect(sanitized.contains('###'), isFalse);
        expect(sanitized.contains('**'), isFalse);
        expect(sanitized.contains('`'), isFalse);
        expect(sanitized.contains('Phytophthora infestans'), isTrue);
        expect(
          sanitized.contains(
            'Tomato Blight is caused by Phytophthora infestans',
          ),
          isTrue,
        );
        expect(sanitized.contains('void test'), isFalse);
      },
    );

    test('sanitizeForSpeech strips inline citation tags and page references', () {
      const input =
          "The annual revenue of Canada is 6,000 USD [Rag_example.pdf, Page 5].";

      final sanitized = service.sanitizeForSpeech(input);

      expect(sanitized, equals('The annual revenue of Canada is 6,000 USD.'));
      expect(sanitized.contains('Rag_example'), isFalse);
      expect(sanitized.contains('Page 5'), isFalse);
    });

    test(
      'sanitizeForSpeech converts mathematical operators and fractions to natural words',
      () {
        const input =
            "Percentage Change = [ (New Value - Old Value) / Old Value ] × 100% at 25°C";

        final sanitized = service.sanitizeForSpeech(input);

        expect(sanitized.contains('divided by'), isTrue);
        expect(sanitized.contains('times'), isTrue);
        expect(sanitized.contains('percent'), isTrue);
        expect(sanitized.contains('degrees celsius'), isTrue);
        expect(sanitized.contains('×'), isFalse);
        expect(sanitized.contains('%'), isFalse);
      },
    );

    test(
      'isContinuation correctly identifies streaming extensions vs new utterances after pause',
      () {
        // Direct extensions
        expect(service.isContinuation('what', 'what is'), isTrue);
        expect(
          service.isContinuation('what is tomato', 'what is tomato blight'),
          isTrue,
        );

        // Same starting word
        expect(service.isContinuation('how are', 'how do you'), isTrue);

        // Disjoint new phrases after a pause
        expect(
          service.isContinuation('tomato blight', 'how to treat'),
          isFalse,
        );
        expect(
          service.isContinuation('what is soil pH', 'and fertilizers'),
          isFalse,
        );
        expect(service.isContinuation('hello', 'davangere market'), isFalse);
      },
    );
  });
}
