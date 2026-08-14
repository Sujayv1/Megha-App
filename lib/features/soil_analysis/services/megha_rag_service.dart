import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../../core/network/http_client_provider.dart';

/// Citation Data Model for Grounded Document Sources
class Citation {
  final int sourceId;
  final String fileName;
  final int pageNumber;
  final String section;
  final String snippet;

  const Citation({
    required this.sourceId,
    required this.fileName,
    required this.pageNumber,
    required this.section,
    required this.snippet,
  });

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'fileName': fileName,
    'pageNumber': pageNumber,
    'section': section,
    'snippet': snippet,
  };

  factory Citation.fromJson(Map<String, dynamic> json) => Citation(
    sourceId: json['sourceId'] as int? ?? 1,
    fileName: json['fileName'] as String? ?? 'Document.pdf',
    pageNumber: json['pageNumber'] as int? ?? 1,
    section: json['section'] as String? ?? '',
    snippet: json['snippet'] as String? ?? '',
  );
}

/// RAG Response Data Model containing Answer & Filtered Citations
class RAGResponse {
  final String answer;
  final List<Citation> citations;
  final double confidenceScore;
  final bool isGrounded;

  const RAGResponse({
    required this.answer,
    required this.citations,
    required this.confidenceScore,
    required this.isGrounded,
  });
}

/// Main MeghaRag Service for Direct Chroma Cloud & Gemini Integration
class MeghaRagService {
  MeghaRagService._();
  static final MeghaRagService instance = MeghaRagService._();

  // Environment Credentials & Configuration
  static String get geminiApiKey => AppConstants.geminiApiKey;
  static const String chromaApiKey =
      'ck-45asi2qrJPZHUcf3EqmyfWiGSidHSo8cwAYa92ju7fKF';
  static const String tenantId = '5b24e72b-47d9-467c-b55e-288db51e3e55';
  static const String database = 'megha';
  static const String collectionName = 'megharag_docs';

  // Resilient Generation Model Cascade (prevents 429 quota exhausted errors)
  static const List<String> _generationModels = [
    'gemini-1.5-flash',
    'gemini-2.0-flash',
    'gemini-3.6-flash',
  ];

  String? _cachedCollectionId;

  http.Client get _client => AppHttpClient.instance;

  /// Fetch and cache Chroma Cloud collection UUID (using v2 API)
  Future<String> _getCollectionId() async {
    if (_cachedCollectionId != null) return _cachedCollectionId!;

    final url = Uri.parse(
      'https://api.trychroma.com/api/v2/tenants/$tenantId/databases/$database/collections/$collectionName',
    );

    final response = await _client.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-chroma-token': chromaApiKey,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _cachedCollectionId = data['id'] as String;
      return _cachedCollectionId!;
    } else {
      throw Exception(
        'Failed to fetch Chroma collection UUID: ${response.body}',
      );
    }
  }

  /// 1. Generate query embedding vector using Gemini Embedding API (gemini-embedding-001)
  Future<List<double>> embedQuery(String text) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=$geminiApiKey',
    );

    final response = await _client.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'models/gemini-embedding-001',
        'content': {
          'parts': [
            {'text': text},
          ],
        },
        'taskType': 'RETRIEVAL_QUERY',
        'outputDimensionality': 3072,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> values = data['embedding']['values'];
      return values.map((v) => (v as num).toDouble()).toList();
    } else {
      throw Exception('Failed to embed query vector: ${response.body}');
    }
  }

  /// 2. Query Chroma Cloud REST API (v2) for top candidate document chunks (with Hybrid Re-ranking)
  Future<List<Map<String, dynamic>>> searchVectorStore(
    List<double> vector, {
    String? originalQuery,
    int topK = 10,
  }) async {
    final collectionId = await _getCollectionId();
    final url = Uri.parse(
      'https://api.trychroma.com/api/v2/tenants/$tenantId/databases/$database/collections/$collectionId/query',
    );

    final response = await _client.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-chroma-token': chromaApiKey,
      },
      body: jsonEncode({
        'query_embeddings': [vector],
        'n_results': 15,
        'include': ['documents', 'metadatas', 'distances'],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['documents'] == null ||
          (data['documents'] as List).isEmpty ||
          (data['documents'][0] as List).isEmpty) {
        return [];
      }

      final documents = data['documents'][0] as List;
      final metadatas = data['metadatas'][0] as List;
      final distances = data['distances'][0] as List;

      bool isContactQuery = false;
      if (originalQuery != null) {
        final qLower = originalQuery.toLowerCase();
        isContactQuery =
            qLower.contains('email') ||
            qLower.contains('mail') ||
            qLower.contains('contact') ||
            qLower.contains('phone') ||
            qLower.contains('address') ||
            qLower.contains('who') ||
            qLower.contains('name');
      }

      final emailRegex = RegExp(
        r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
      );

      List<Map<String, dynamic>> candidateChunks = [];
      for (int i = 0; i < documents.length; i++) {
        double dist = (distances[i] as num).toDouble();
        double simScore = 1.0 / (1.0 + (dist < 0 ? 0 : dist));
        final text = documents[i] as String;

        // Hybrid Re-ranking: Boost chunks containing email/phone when user asks contact query
        if (isContactQuery && emailRegex.hasMatch(text)) {
          simScore += 1.0; // Massive boost so contact chunk jumps to RANK #1!
        }

        candidateChunks.add({
          'source_id': i + 1,
          'text': text,
          'metadata': (metadatas[i] as Map<String, dynamic>?) ?? {},
          'similarity_score': simScore,
        });
      }

      candidateChunks.sort(
        (a, b) => (b['similarity_score'] as double).compareTo(
          a['similarity_score'] as double,
        ),
      );
      return candidateChunks.take(topK).toList();
    } else {
      throw Exception('Failed to query Chroma Cloud: ${response.body}');
    }
  }

  /// 3. Execute Complete Grounded RAG Pipeline with Fallback Models
  Future<RAGResponse> query(String queryText) async {
    try {
      // A. Embed query
      final vector = await embedQuery(queryText);

      // B. Search Chroma Cloud with Hybrid Contact Re-ranking
      final retrievedChunks = await searchVectorStore(
        vector,
        originalQuery: queryText,
        topK: 10,
      );

      // C. Build formatted document context string
      StringBuffer contextBuffer = StringBuffer();
      List<Citation> allCitations = [];

      for (int i = 0; i < retrievedChunks.length; i++) {
        final chunk = retrievedChunks[i];
        final meta = chunk['metadata'] as Map<String, dynamic>;
        int sourceId = i + 1;

        final fileName = (meta['file_name'] ?? meta['source'] ?? 'Document.pdf')
            .toString();
        final pageNum = meta['page_number'] != null
            ? int.tryParse(meta['page_number'].toString()) ?? 1
            : 1;
        final sectionName = (meta['section'] ?? '').toString();
        final textSnippet = chunk['text'] as String;

        contextBuffer.writeln(
          '[SOURCE $sourceId] File: $fileName (Page $pageNum)',
        );
        contextBuffer.writeln(textSnippet);
        contextBuffer.writeln();

        allCitations.add(
          Citation(
            sourceId: sourceId,
            fileName: fileName,
            pageNumber: pageNum,
            section: sectionName,
            snippet: textSnippet.length > 120
                ? '${textSnippet.substring(0, 120)}...'
                : textSnippet,
          ),
        );
      }

      final combinedContext =
          '--- RETRIEVED DOCUMENT CONTEXT ---\n${contextBuffer.isEmpty ? "No specific document chunks retrieved for this question." : contextBuffer}';

      // D. Call Gemini Generation API with automatic model fallback to avoid 429 quota limits
      String? rawAnswer;
      String? lastError;

      for (final modelName in _generationModels) {
        final geminiUrl = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$geminiApiKey',
        );

        final response = await _client.post(
          geminiUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'system_instruction': {
              'parts': [
                {
                  'text':
                      'You are MeghaRag, an intelligent AI assistant delivering clean, beautifully structured, ChatGPT-style answers based ONLY on RETRIEVED DOCUMENT CONTEXT.\n\nStrict Output Guidelines:\n1. Answer the user question using ONLY factual information from the RETRIEVED DOCUMENT CONTEXT.\n2. Format your response using clean Markdown formatting with bold titles (**Title:**) and bullet points (- Item).\n3. Do NOT spam or append `[SOURCE X]` tags to every sentence or line. Keep the main body text clean and readable.\n4. If information is missing from the retrieved documents, state: "I couldn\'t find sufficient information in the uploaded documents to answer this question."',
                },
              ],
            },
            'contents': [
              {
                'parts': [
                  {
                    'text':
                        '$combinedContext\n--- USER QUESTION ---\n$queryText\n\n--- GROUNDED ANSWER ---',
                  },
                ],
              },
            ],
            'generationConfig': {'temperature': 0.2, 'maxOutputTokens': 1000},
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          rawAnswer =
              data['candidates'][0]['content']['parts'][0]['text'] as String;
          break; // Success! Break out of model fallback loop
        } else {
          lastError = response.body;
          // If 429 or 404, try next fallback model in list
          continue;
        }
      }

      if (rawAnswer != null) {
        // Smart Citation Filter: Only return citations explicitly referenced in the answer
        RegExp exp = RegExp(r'\[(?:SOURCE\s*)?(\d+)\]', caseSensitive: false);
        Iterable<RegExpMatch> matches = exp.allMatches(rawAnswer);
        Set<int> referencedIds = matches
            .map((m) => int.parse(m.group(1)!))
            .toSet();

        List<Citation> matchedCitations = allCitations
            .where((c) => referencedIds.contains(c.sourceId))
            .toList();

        List<Citation> candidateCitations = matchedCitations.isEmpty
            ? allCitations
            : matchedCitations;

        // Deduplicate by unique file name so same document isn't listed multiple times
        final Map<String, Citation> uniqueFileMap = {};
        for (var c in candidateCitations) {
          if (!uniqueFileMap.containsKey(c.fileName)) {
            uniqueFileMap[c.fileName] = c;
          }
        }

        return RAGResponse(
          answer: rawAnswer,
          citations: retrievedChunks.isEmpty
              ? []
              : uniqueFileMap.values.toList(),
          confidenceScore: 0.95,
          isGrounded: true,
        );
      } else {
        throw Exception('All Gemini generation models failed: $lastError');
      }
    } catch (e) {
      return RAGResponse(
        answer:
            "I encountered an issue processing your query: ${e.toString().replaceAll(RegExp(r'AQ\.[a-zA-Z0-9_-]+'), '[REDACTED]')}",
        citations: [],
        confidenceScore: 0.0,
        isGrounded: false,
      );
    }
  }
}
