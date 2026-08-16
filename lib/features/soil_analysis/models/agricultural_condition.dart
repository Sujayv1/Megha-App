/// Scientific Condition Model representing an evaluated agronomic dimension
/// (Vegetation Health, Water Stress, Heat Stress, Drought Risk, Vegetation Water).
class AgriculturalCondition {
  final String title;
  final String status;
  final String severity; // NONE, LOW, MODERATE, HIGH, CRITICAL, UNAVAILABLE
  final String explanation; // Farmer-friendly actionable explanation
  final String technicalSummary; // Scientific rationale
  final Map<String, String> supportingMetrics; // e.g. {"NDVI": "0.72", "NDRE": "0.31"}
  final String confidence; // HIGH, MEDIUM, LOW
  final List<String> sources; // Real sources used (e.g. Sentinel-2, ECMWF)
  final bool isUnavailable;
  final String? unavailableReason;

  const AgriculturalCondition({
    required this.title,
    required this.status,
    required this.severity,
    required this.explanation,
    required this.technicalSummary,
    required this.supportingMetrics,
    required this.confidence,
    required this.sources,
    this.isUnavailable = false,
    this.unavailableReason,
  });

  /// Factory for when necessary observations are absent.
  factory AgriculturalCondition.unavailable({
    required String title,
    required String reason,
    List<String> sources = const [],
  }) {
    return AgriculturalCondition(
      title: title,
      status: 'UNAVAILABLE',
      severity: 'UNAVAILABLE',
      explanation: 'Sufficient data unavailable to compute $title at this moment.',
      technicalSummary: reason,
      supportingMetrics: const {},
      confidence: 'LOW',
      sources: sources,
      isUnavailable: true,
      unavailableReason: reason,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'status': status,
        'severity': severity,
        'explanation': explanation,
        'technicalSummary': technicalSummary,
        'supportingMetrics': supportingMetrics,
        'confidence': confidence,
        'sources': sources,
        'isUnavailable': isUnavailable,
        'unavailableReason': unavailableReason,
      };
}
