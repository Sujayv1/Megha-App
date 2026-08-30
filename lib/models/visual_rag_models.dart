/// Data models for Visual RAG retrieval & response formatting (Text & Citation Score Only).
class DocumentCitation {
  final String filename;
  final int pageNumber;
  final double score;

  const DocumentCitation({
    required this.filename,
    required this.pageNumber,
    required this.score,
  });

  factory DocumentCitation.fromJson(Map<String, dynamic> json) {
    return DocumentCitation(
      filename: json['filename'] as String? ??
          json['file_name'] as String? ??
          json['fileName'] as String? ??
          'document.pdf',
      pageNumber: (json['page_number'] as num? ??
              json['pageNumber'] as num? ??
              1)
          .toInt(),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'filename': filename,
    'page_number': pageNumber,
    'score': score,
  };

  /// Formatted citation title (e.g. "Rag_example.pdf (Page 6)")
  String get displayName => "$filename (Page $pageNumber)";

  /// Confidence score formatted as percentage out of 100% (e.g. "94.5%")
  String get confidencePercentage {
    final pct = (score * 100).clamp(0.0, 100.0);
    return "${pct.toStringAsFixed(1)}%";
  }

  /// Clean one-line citation string (e.g. "Rag_example.pdf (Page 6) • 94.5% match")
  String get formattedCitation => "$displayName • $confidencePercentage match";
}

class VisualRagResponse {
  final String answer;
  final List<DocumentCitation> citations;
  final double totalTimeMs;

  const VisualRagResponse({
    required this.answer,
    required this.citations,
    required this.totalTimeMs,
  });

  factory VisualRagResponse.fromJson(Map<String, dynamic> json) {
    return VisualRagResponse(
      answer: json['answer'] as String? ?? '',
      citations: (json['sources'] as List<dynamic>? ??
                  json['citations'] as List<dynamic>?)
              ?.map((s) => DocumentCitation.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
      totalTimeMs: (json['total_time_ms'] as num? ??
              json['totalTimeMs'] as num? ??
              0.0)
          .toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'answer': answer,
    'citations': citations.map((c) => c.toJson()).toList(),
    'total_time_ms': totalTimeMs,
  };
}
