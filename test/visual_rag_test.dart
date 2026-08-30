import 'package:flutter_test/flutter_test.dart';
import 'package:plant_project/models/visual_rag_models.dart';
import 'package:plant_project/services/visual_rag_service.dart';
import 'package:plant_project/features/soil_analysis/services/megha_chat_storage_service.dart';

void main() {
  group('Visual RAG Data Models & Citations Formatting Tests', () {
    test('DocumentCitation format test (Text & Percentage Only - No Images)', () {
      final citation = DocumentCitation(
        filename: 'Crop_Diagnostics_Guide.pdf',
        pageNumber: 6,
        score: 0.9248,
      );

      expect(citation.displayName, equals('Crop_Diagnostics_Guide.pdf (Page 6)'));
      expect(citation.confidencePercentage, equals('92.5%'));
      expect(
        citation.formattedCitation,
        equals('Crop_Diagnostics_Guide.pdf (Page 6) • 92.5% match'),
      );
    });

    test('DocumentCitation JSON serialization & deserialization', () {
      final jsonMap = {
        'filename': 'Soil_Health_Manual.pdf',
        'page_number': 14,
        'score': 0.887,
      };

      final citation = DocumentCitation.fromJson(jsonMap);
      expect(citation.filename, equals('Soil_Health_Manual.pdf'));
      expect(citation.pageNumber, equals(14));
      expect(citation.score, closeTo(0.887, 0.0001));
      expect(citation.confidencePercentage, equals('88.7%'));

      final serialized = citation.toJson();
      expect(serialized['filename'], equals('Soil_Health_Manual.pdf'));
      expect(serialized['page_number'], equals(14));
      expect(serialized['score'], equals(0.887));
    });

    test('VisualRagResponse JSON serialization & parsing', () {
      final responseMap = {
        'answer': 'Tomato blight can be controlled with copper fungicide.',
        'sources': [
          {
            'filename': 'Tomato_Pathology.pdf',
            'page_number': 3,
            'score': 0.952,
          }
        ],
        'total_time_ms': 342.5,
      };

      final ragResponse = VisualRagResponse.fromJson(responseMap);
      expect(ragResponse.answer, contains('Tomato blight'));
      expect(ragResponse.citations.length, equals(1));
      expect(
        ragResponse.citations.first.formattedCitation,
        equals('Tomato_Pathology.pdf (Page 3) • 95.2% match'),
      );
      expect(ragResponse.totalTimeMs, equals(342.5));
    });

    test('ChatMessageModel with DocumentCitation serialization', () {
      final message = ChatMessageModel(
        role: 'assistant',
        content: 'Apply potassium fertilizer for better root development.',
        timestamp: DateTime(2026, 8, 30, 14, 0),
        citations: [
          const DocumentCitation(
            filename: 'Fertilizer_Guide.pdf',
            pageNumber: 12,
            score: 0.91,
          ),
        ],
      );

      final json = message.toJson();
      final restored = ChatMessageModel.fromJson(json);

      expect(restored.role, equals('assistant'));
      expect(restored.content, equals(message.content));
      expect(restored.citations, isNotNull);
      expect(restored.citations!.length, equals(1));
      expect(
        restored.citations!.first.formattedCitation,
        equals('Fertilizer_Guide.pdf (Page 12) • 91.0% match'),
      );
    });

    test('VisualRagService instant greeting returns without cloud delay', () async {
      final service = VisualRagService.instance;
      final response = await service.ask('hello');

      expect(response.answer, contains('Namaste'));
      expect(response.citations, isEmpty);
      expect(response.totalTimeMs, equals(0.0));
    });

    test('VisualRagService live document question answering and citation matching', () async {
      final service = VisualRagService.instance;
      final response = await service.ask('whats the annual revenue of mexico?');

      expect(response.answer, isNotEmpty);
      expect(response.answer.toLowerCase(), contains('5,500'));
      // Inline citation brackets should NOT be in the answer text
      expect(response.answer.contains('[Rag_example.pdf'), isFalse);
      expect(response.citations, isNotEmpty);
      expect(response.citations.first.displayName, contains('Page 5'));
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('VisualRagService formula query returns clean human-readable math without LaTeX syntax', () async {
      final service = VisualRagService.instance;
      final response = await service.ask("what's the formula for percentage change?");

      expect(response.answer, isNotEmpty);
      // Ensure no raw LaTeX artifact remains
      expect(response.answer.contains(r'\left'), isFalse);
      expect(response.answer.contains(r'\right'), isFalse);
      expect(response.answer.contains(r'\frac'), isFalse);
      expect(response.answer.contains(r'\text'), isFalse);
      expect(response.answer.contains(r'$$'), isFalse);
      expect(response.answer.contains('[Rag_example.pdf'), isFalse);

      expect(response.citations, isNotEmpty);
      expect(response.citations.first.displayName, contains('Page 8'));
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}
