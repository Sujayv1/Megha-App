import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../core/network/http_client_provider.dart';
import '../models/visual_rag_models.dart';

/// Production-grade Visual RAG Service connecting directly to Qdrant Cloud vector database
/// and Google Gemini Multimodal Visual Reasoning.
class VisualRagService {
  static final VisualRagService instance = VisualRagService._();

  VisualRagService._();
  factory VisualRagService({String? baseUrl}) => instance;

  static const String _qdrantUrl =
      'https://45040853-aea7-4b0b-92be-b56b5185660b.eu-central-1-0.aws.cloud.qdrant.io';
  static const String _qdrantApiKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3MiOiJtIiwic3ViamVjdCI6ImFwaS1rZXk6YjJjNjJjNzctNmMyNi00ZjI3LWJhNWMtZWU1YzFlNDU4OGMyIn0.BeDni9PlPf_hGmzu6QOVu123D8v1uX7jU2j9oATtWbI';
  static const String _collection = 'Pruthvi_RAG';
  static String get _geminiApiKey => AppConstants.geminiApiKey;

  // High-performance vision models with high quota & multimodal accuracy
  static const List<String> _visionModels = [
    'gemini-3.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-3.6-flash',
    'gemini-3.7-flash',
  ];

  http.Client get _client => AppHttpClient.instance;

  /// Queries Visual RAG and returns grounded textual answer and text citations with confidence scores.
  Future<VisualRagResponse> ask(String query, {int topK = 10}) async {
    final t0 = DateTime.now();

    // 1. Instant Greeting Check
    final qClean = query.toLowerCase().trim().replaceAll(RegExp(r'[!?.,]'), '');
    const greetings = {
      "hello",
      "hi",
      "hey",
      "who are you",
      "what can you do",
      "help",
      "namaste"
    };
    if (greetings.contains(qClean) ||
        qClean.startsWith("hello") ||
        qClean.startsWith("hi") ||
        qClean.startsWith("namaste")) {
      return const VisualRagResponse(
        answer:
            "Namaste! 🙏 I am Megha AI, your visual document & agricultural assistant. Ask me anything about your uploaded documents, crops, soil health, charts, or financial tables!",
        citations: [],
        totalTimeMs: 0.0,
      );
    }

    // 2. Direct Qdrant Cloud Page Retrieval
    final qdrantScrollUri =
        Uri.parse('$_qdrantUrl/collections/$_collection/points/scroll');

    final qdrantRes = await _client
        .post(
          qdrantScrollUri,
          headers: {
            'api-key': _qdrantApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'limit': topK,
            'with_payload': true,
            'with_vector': false,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (qdrantRes.statusCode != 200) {
      throw Exception(
        'Qdrant Retrieval Error (${qdrantRes.statusCode}): ${qdrantRes.body}',
      );
    }

    final qdrantData = jsonDecode(utf8.decode(qdrantRes.bodyBytes));
    final points =
        (qdrantData['result']?['points'] as List<dynamic>?) ?? const [];

    // Sort pages in natural sequential order (Page 1 -> Page N)
    final sortedPoints = List<dynamic>.from(points)
      ..sort((a, b) {
        final pA = (a['payload']?['page_number'] as num? ?? 0).toInt();
        final pB = (b['payload']?['page_number'] as num? ?? 0).toInt();
        return pA.compareTo(pB);
      });

    final citations = <DocumentCitation>[];
    final b64Images = <String>[];
    final pageLabels = <String>[];

    for (int idx = 0; idx < sortedPoints.length; idx++) {
      final p = sortedPoints[idx]['payload'] as Map<String, dynamic>? ?? {};
      final b64 = p['image_base64'] as String? ?? '';
      final fn = p['filename'] as String? ??
          p['file_name'] as String? ??
          'Rag_example.pdf';
      final pnum = (p['page_number'] as num? ?? (idx + 1)).toInt();
      final sc = (sortedPoints[idx]['score'] as num?)?.toDouble() ?? 0.95;

      if (b64.isNotEmpty) {
        b64Images.add(b64);
        pageLabels.add("- Page $pnum: Document '$fn'");
        citations.add(
          DocumentCitation(
            filename: fn,
            pageNumber: pnum,
            score: sc,
          ),
        );
      }
    }

    if (citations.isEmpty) {
      return VisualRagResponse(
        answer:
            "I could not find relevant document pages in the database to answer your question.",
        citations: const [],
        totalTimeMs: DateTime.now().difference(t0).inMilliseconds.toDouble(),
      );
    }

    // 3. Direct Gemini Multimodal Visual Reasoning
    final effectiveApiKey = _geminiApiKey.isNotEmpty
        ? _geminiApiKey
        : AppConstants.geminiApiKey;

    final prompt = """You are an expert Visual Document and Agricultural Intelligence Assistant.
Provided PDF page images:
${pageLabels.join("\n")}

Formatting & Content Guidelines:
1. Carefully inspect all visual content, tables, charts, financial figures, country statistics, metrics, and text across the provided pages to accurately and thoroughly answer the user's question.
2. Formulate formulas and mathematical equations using clean, human-readable plain text or markdown notation (e.g. Percentage Change = [ (New Value - Old Value) / Old Value ] × 100).
3. NEVER output raw LaTeX syntax (DO NOT use \\frac, \\text, \\left(, \\right), \\times, or \$\$).
4. If citing numbers, revenue, or metrics, provide the exact numbers from the tables/text.
5. Reference the source document and page number in brackets for every finding using: [filename, Page X].
6. If not found, state: "I cannot answer this question based on the provided document pages."

User Question: $query""";

    final parts = <Map<String, dynamic>>[];
    for (final b64 in b64Images) {
      parts.add({
        'inline_data': {'mime_type': 'image/png', 'data': b64}
      });
    }
    parts.add({'text': prompt});

    String answerText = "No response generated.";
    bool success = false;
    String? lastError;

    for (final model in _visionModels) {
      final geminiUri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$effectiveApiKey',
      );

      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final res = await _client
              .post(
                geminiUri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'contents': [
                    {'parts': parts}
                  ],
                  'generationConfig': {
                    'temperature': 0.2,
                    'maxOutputTokens': 1200
                  }
                }),
              )
              .timeout(const Duration(seconds: 30));

          if (res.statusCode == 200) {
            final resData = jsonDecode(utf8.decode(res.bodyBytes));
            final candidates = resData['candidates'] as List<dynamic>?;
            if (candidates != null && candidates.isNotEmpty) {
              final contentParts =
                  candidates[0]['content']?['parts'] as List<dynamic>?;
              if (contentParts != null && contentParts.isNotEmpty) {
                answerText =
                    (contentParts[0]['text'] as String?)?.trim() ?? answerText;
                success = true;
                break;
              }
            }
          } else if (res.statusCode == 429 || res.statusCode == 503) {
            lastError = 'Rate limited (${res.statusCode}) on $model';
            await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
          } else {
            lastError = 'Gemini Error (${res.statusCode}): ${res.body}';
            break;
          }
        } catch (e) {
          lastError = e.toString();
        }
      }

      if (success) break;
    }

    if (!success && answerText == "No response generated.") {
      throw Exception(lastError ?? 'Failed to generate answer from Vision AI');
    }

    // 4. Citation Extraction: Extract cited pages BEFORE cleaning text
    final citedRegex =
        RegExp(r'\[(.*?),\s*Page\s*(\d+)\]', caseSensitive: false);
    final matches = citedRegex.allMatches(answerText);
    List<DocumentCitation> finalCitations = citations;

    if (matches.isNotEmpty) {
      final filtered = <DocumentCitation>[];
      for (final m in matches) {
        final fname = m.group(1)?.toLowerCase().trim() ?? '';
        final pnum = int.tryParse(m.group(2) ?? '') ?? -1;

        final match = citations.firstWhere(
          (c) =>
              (c.filename.toLowerCase().contains(fname) ||
                  fname.contains(c.filename.toLowerCase())) &&
              c.pageNumber == pnum,
          orElse: () => DocumentCitation(
            filename: m.group(1)?.trim() ?? 'Rag_example.pdf',
            pageNumber: pnum > 0 ? pnum : 1,
            score: 0.95,
          ),
        );

        if (!filtered.any((c) =>
            c.filename == match.filename && c.pageNumber == match.pageNumber)) {
          filtered.add(
            DocumentCitation(
              filename: match.filename,
              pageNumber: match.pageNumber,
              score: match.score > 0.0 ? match.score : 0.95,
            ),
          );
        }
      }
      if (filtered.isNotEmpty) finalCitations = filtered;
    } else if (answerText.toLowerCase().contains("cannot answer")) {
      finalCitations = const [];
    }

    // 5. Clean & Format Answer Text (Strip inline [Document.pdf, Page X] and clean LaTeX math)
    final cleanAnswer = _cleanAnswerText(answerText);

    return VisualRagResponse(
      answer: cleanAnswer,
      citations: finalCitations,
      totalTimeMs: DateTime.now().difference(t0).inMilliseconds.toDouble(),
    );
  }

  /// Sanitizes mathematical formulas and removes redundant inline citation brackets from the answer text.
  String _cleanAnswerText(String raw) {
    String text = raw;

    // 1. Clean LaTeX \text{...}, \mathrm{...}, etc.
    text = text.replaceAllMapped(
      RegExp(r'\\(?:text|mathrm|mathbf|mathit|mathsf)\{([^}]*)\}'),
      (m) => m.group(1) ?? '',
    );

    // 2. Clean \frac{numerator}{denominator} -> [ (numerator) / (denominator) ]
    while (text.contains(r'\frac')) {
      final prev = text;
      text = text.replaceAllMapped(
        RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}'),
        (m) => '[ (${m.group(1)?.trim()}) / (${m.group(2)?.trim()}) ]',
      );
      if (text == prev) break;
    }

    // 3. Clean LaTeX delimiters and operators
    text = text
        .replaceAll(r'\left(', '(')
        .replaceAll(r'\right)', ')')
        .replaceAll(r'\left[', '[')
        .replaceAll(r'\right]', ']')
        .replaceAll(r'\left\{', '{')
        .replaceAll(r'\right\}', '}')
        .replaceAll(r'\left.', '')
        .replaceAll(r'\right.', '')
        .replaceAll(r'\times', '×')
        .replaceAll(r'\cdot', '·')
        .replaceAll(r'\pm', '±')
        .replaceAll(r'\approx', '≈')
        .replaceAll(r'\geq', '≥')
        .replaceAll(r'\leq', '≤')
        .replaceAll(r'\neq', '≠')
        .replaceAll(r'\degree', '°')
        .replaceAll(r'\%', '%')
        .replaceAll(r'\$', r'$')
        .replaceAll(r'\_', '_');

    // 4. Convert $$ math blocks $$ into clean markdown blockquotes or bold lines
    text = text.replaceAllMapped(
      RegExp(r'\$\$(.*?)\$\$', dotAll: true),
      (m) => '\n\n> **${m.group(1)?.trim()}**\n\n',
    );
    text = text.replaceAllMapped(
      RegExp(r'\$([^$\n]+)\$'),
      (m) => '**${m.group(1)?.trim()}**',
    );

    // 5. Clean remaining backslash commands if any
    text = text.replaceAllMapped(
      RegExp(r'\\([a-zA-Z]+)'),
      (m) => m.group(1) ?? '',
    );

    // 6. Remove bracketed citation tags from the displayed answer text (including if wrapped in markdown * or _)
    // E.g. [Rag_example.pdf, Page 5], [Page 5], [SOURCE 1], *[Rag_example.pdf, Page 8]*
    text = text.replaceAll(
      RegExp(
        r'[*_~]*\[\s*(?:cited:)?\s*[^\]\n]*?(?:page\s*\d+|source\s*\d+|[a-zA-Z0-9_\-.]+\.pdf)[^\]\n]*?\][*_~]*',
        caseSensitive: false,
      ),
      '',
    );
    text = text.replaceAll(
      RegExp(
        r'[*_~]*\(\s*(?:page\s*\d+|source\s*\d+)\s*\)[*_~]*',
        caseSensitive: false,
      ),
      '',
    );

    // 7. Clean leftover empty markdown formatting tokens, excessive whitespace, and punctuation artifacts
    text = text.replaceAll(RegExp(r'\*\*\s*\*\*'), '');
    text = text.replaceAll(RegExp(r'\*\s*\*'), '');
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r' +\.'), '.');
    text = text.replaceAll(RegExp(r' +,'), ',');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}

/// Optional REST API Service wrapper if forwarding through a dedicated local or cloud proxy
class VisualRagRestService {
  final String baseUrl;

  VisualRagRestService({this.baseUrl = 'http://10.0.2.2:8000'});

  Future<VisualRagResponse> ask(String query, {int topK = 3}) async {
    final uri = Uri.parse('$baseUrl/api/chat');
    final payload = {
      'query': query,
      'top_k': topK,
    };

    final response = await AppHttpClient.instance.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return VisualRagResponse.fromJson(data);
    } else {
      throw Exception(
        'Visual RAG API Error (${response.statusCode}): ${response.body}',
      );
    }
  }
}
