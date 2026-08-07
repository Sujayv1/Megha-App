import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/soil_data_model.dart';
import '../../../core/constants/app_constants.dart';

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  final String _endpoint =
      '${AppConstants.geminiBaseUrl}/${AppConstants.geminiModel}:generateContent';

  /// Analyzes a soil report file (image or PDF) using Gemini vision API.
  /// Returns a [SoilDataModel] parsed from Gemini's structured JSON response.
  Future<SoilDataModel> analyzeSoilReport(File file) async {
    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);
    final mimeType = _getMimeType(file.path);

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': AppConstants.soilAnalysisPrompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Data,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.1,
        'topP': 0.8,
        'maxOutputTokens': 8192, // Increased from 2048 to 8192 for large reports
      },
    };

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'X-goog-api-key': AppConstants.geminiApiKey,
          },
          body: jsonEncode(requestBody),
        )
        .timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      final error = _parseError(response.body);
      throw GeminiException('Gemini API error (${response.statusCode}): $error');
    }

    return _parseResponse(response.body);
  }

  // ─── Private Helpers ────────────────────────────────────────────────────────

  String _getMimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    return switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  SoilDataModel _parseResponse(String responseBody) {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;

    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw const GeminiException('No response candidates from Gemini');
    }

    final candidate = candidates[0] as Map<String, dynamic>;
    final content = candidate['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      final finishReason = candidate['finishReason']?.toString();
      throw GeminiException('Empty content from Gemini (finishReason: $finishReason)');
    }

    final rawText = parts[0]['text']?.toString() ?? '';

    // Strip markdown code fences if present
    String cleaned = rawText.trim();
    if (cleaned.startsWith('```')) {
      final firstNewline = cleaned.indexOf('\n');
      if (firstNewline != -1) {
        cleaned = cleaned.substring(firstNewline + 1);
      }
      final lastFence = cleaned.lastIndexOf('```');
      if (lastFence != -1) {
        cleaned = cleaned.substring(0, lastFence);
      }
      cleaned = cleaned.trim();
    }

    // Ensure we start at the outer opening brace '{'
    final firstBrace = cleaned.indexOf('{');
    if (firstBrace != -1) {
      cleaned = cleaned.substring(firstBrace);
    }

    try {
      final jsonData = _safeDecodeJson(cleaned);
      return SoilDataModel.fromJson(jsonData);
    } catch (e) {
      final snippet =
          cleaned.length > 250 ? '${cleaned.substring(0, 250)}...' : cleaned;
      throw GeminiException('Failed to parse Gemini JSON response: $e\nRaw: $snippet');
    }
  }

  Map<String, dynamic> _safeDecodeJson(String text) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      // Attempt JSON repair for truncated or malformed responses
      String repaired = text.trim();
      repaired = repaired.replaceAll(RegExp(r',?\s*"[^"]*$'), '');
      repaired = repaired.replaceAll(RegExp(r',\s*$'), '');

      int openBraces = 0;
      int openBrackets = 0;
      bool inString = false;
      bool escape = false;

      for (int i = 0; i < repaired.length; i++) {
        final char = repaired[i];
        if (escape) {
          escape = false;
          continue;
        }
        if (char == '\\') {
          escape = true;
          continue;
        }
        if (char == '"') {
          inString = !inString;
          continue;
        }
        if (!inString) {
          if (char == '{') openBraces++;
          if (char == '}') openBraces--;
          if (char == '[') openBrackets++;
          if (char == ']') openBrackets--;
        }
      }

      if (inString) repaired += '"';
      while (openBrackets > 0) {
        repaired += ']';
        openBrackets--;
      }
      while (openBraces > 0) {
        repaired += '}';
        openBraces--;
      }

      return jsonDecode(repaired) as Map<String, dynamic>;
    }
  }

  String _parseError(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded['error']?['message']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }
}

class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);

  @override
  String toString() => 'GeminiException: $message';
}
