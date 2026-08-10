double _safeDouble(dynamic val, [double defaultValue = 0.0]) {
  if (val == null) return defaultValue;
  if (val is num) return val.toDouble();
  final parsed = double.tryParse(val.toString());
  return parsed ?? defaultValue;
}

class MandiPriceRecord {
  final String market;
  final String district;
  final String state;
  final String commodity;
  final String variety;
  final String grade;
  final double modalPriceQuintal;
  final double modalPriceKg;
  final double minPriceQuintal;
  final double minPriceKg;
  final double maxPriceQuintal;
  final double maxPriceKg;
  final String arrivalDate;

  const MandiPriceRecord({
    required this.market,
    required this.district,
    required this.state,
    required this.commodity,
    required this.variety,
    required this.grade,
    required this.modalPriceQuintal,
    required this.modalPriceKg,
    required this.minPriceQuintal,
    required this.minPriceKg,
    required this.maxPriceQuintal,
    required this.maxPriceKg,
    required this.arrivalDate,
  });

  factory MandiPriceRecord.fromJson(
    Map<String, dynamic> json,
    String fallbackDistrict,
    String fallbackState,
    String fallbackCommodity,
  ) {
    final modalP = _safeDouble(
      json['modal_price_quintal'] ?? json['modal_price'],
    );
    final minPRaw = _safeDouble(
      json['min_price_quintal'] ?? json['min_price'],
      modalP,
    );
    final maxPRaw = _safeDouble(
      json['max_price_quintal'] ?? json['max_price'],
      modalP,
    );

    final minP = minPRaw > 0 ? minPRaw : modalP;
    final maxP = maxPRaw > 0 ? maxPRaw : modalP;

    final rawModalKg = json['modal_price_kg'];
    final modalKg = rawModalKg != null
        ? _safeDouble(rawModalKg, modalP / 100.0)
        : (modalP / 100.0);
    final minKg = minP / 100.0;
    final maxKg = maxP / 100.0;

    return MandiPriceRecord(
      market: json['market']?.toString() ?? 'Local Mandi',
      district: json['district']?.toString() ?? fallbackDistrict,
      state: json['state']?.toString() ?? fallbackState,
      commodity: json['commodity']?.toString() ?? fallbackCommodity,
      variety: json['variety']?.toString() ?? 'Standard',
      grade: json['grade']?.toString() ?? 'Grade A',
      modalPriceQuintal: modalP,
      modalPriceKg: _safeDouble(modalKg.toStringAsFixed(2)),
      minPriceQuintal: minP,
      minPriceKg: _safeDouble(minKg.toStringAsFixed(2)),
      maxPriceQuintal: maxP,
      maxPriceKg: _safeDouble(maxKg.toStringAsFixed(2)),
      arrivalDate: json['arrival_date']?.toString() ?? 'Latest',
    );
  }
}

class MandiHighestRecord {
  final String market;
  final String district;
  final String state;
  final double maxPriceQuintal;
  final double maxPriceKg;
  final double modalPriceQuintal;
  final String variety;
  final String arrivalDate;

  const MandiHighestRecord({
    required this.market,
    required this.district,
    required this.state,
    required this.maxPriceQuintal,
    required this.maxPriceKg,
    required this.modalPriceQuintal,
    required this.variety,
    required this.arrivalDate,
  });

  factory MandiHighestRecord.fromJson(Map<String, dynamic> json) {
    final maxP = _safeDouble(json['max_price_quintal'] ?? json['max_price']);
    final modalP = _safeDouble(
      json['modal_price_quintal'] ?? json['modal_price'],
      maxP,
    );
    final rawMaxKg = json['max_price_kg'];
    final maxKg = rawMaxKg != null
        ? _safeDouble(rawMaxKg, maxP / 100.0)
        : (maxP / 100.0);

    return MandiHighestRecord(
      market: json['market']?.toString() ?? 'Unknown Market',
      district: json['district']?.toString() ?? 'Unknown District',
      state: json['state']?.toString() ?? 'Unknown State',
      maxPriceQuintal: maxP,
      maxPriceKg: _safeDouble(maxKg.toStringAsFixed(2)),
      modalPriceQuintal: modalP,
      variety: json['variety']?.toString() ?? 'Standard',
      arrivalDate: json['arrival_date']?.toString() ?? 'Latest',
    );
  }
}

class MandiResponse {
  final String queryState;
  final String queryDistrict;
  final String queryCommodity;
  final List<MandiPriceRecord> localMandis;
  final String scopeNote;
  final MandiHighestRecord? highest;
  final double? diffAmountQuintal;
  final double? diffPercent;

  const MandiResponse({
    required this.queryState,
    required this.queryDistrict,
    required this.queryCommodity,
    required this.localMandis,
    required this.scopeNote,
    this.highest,
    this.diffAmountQuintal,
    this.diffPercent,
  });
}
