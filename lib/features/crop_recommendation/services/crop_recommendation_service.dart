import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../soil_analysis/models/soil_data_model.dart';
import '../../soil_analysis/services/soil_storage_service.dart';
import '../models/crop_plan_model.dart';


class CropRecommendationException implements Exception {
  final String message;
  CropRecommendationException(this.message);

  @override
  String toString() => 'CropRecommendationException: $message';
}

class CropRecommendationService {
  CropRecommendationService._();
  static final CropRecommendationService instance =
      CropRecommendationService._();

  static String get _endpoint =>
      '${AppConstants.geminiBaseUrl}/${AppConstants.geminiModel}:generateContent';
  final http.Client _client = http.Client();

  /// Fetches live weather data for city/state via Open-Meteo API.
  Future<String> _fetchLiveWeatherSummary(String city, String state) async {
    try {
      final encodedCity = Uri.encodeComponent(city.trim());
      final geoUrl =
          Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=$encodedCity&count=1');
      final geoRes = await _client.get(geoUrl).timeout(const Duration(seconds: 4));


      if (geoRes.statusCode == 200) {
        final geoData = jsonDecode(geoRes.body);
        final results = geoData['results'] as List<dynamic>?;
        if (results != null && results.isNotEmpty) {
          final lat = results[0]['latitude'];
          final lon = results[0]['longitude'];

          final weatherUrl = Uri.parse(
              'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true&daily=temperature_2m_max,temperature_2m_min,precipitation_sum&timezone=auto');
          final weatherRes =
              await _client.get(weatherUrl).timeout(const Duration(seconds: 4));

          if (weatherRes.statusCode == 200) {
            final wData = jsonDecode(weatherRes.body);
            final cw = wData['current_weather'];
            final temp = cw['temperature'];
            final wind = cw['windspeed'];
            return 'Live Weather in $city, $state: Current Temp: $temp°C, Wind Speed: ${wind}km/h.';

          }
        }
      }
    } catch (_) {
      // Fallback if network timeout occurs
    }
    return 'Regional Agro-Climate: Seasonally monitored temperature & humidity profile for $city, $state.';
  }

  /// Normalizes state names for fuzzy matching.
  bool _areStatesMatching(String s1, String s2) {
    final norm1 = s1.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final norm2 = s2.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    return norm1.contains(norm2) || norm2.contains(norm1);
  }

  /// Validates whether the city/district exists in India and belongs to the selected state.
  Future<void> validateLocation(String city, String state) async {
    final trimmedCity = city.trim();
    if (trimmedCity.isEmpty) {
      throw CropRecommendationException('Please enter a valid city or district name.');
    }

    try {
      final encodedCity = Uri.encodeComponent(trimmedCity);
      final url = Uri.parse(
          'https://geocoding-api.open-meteo.com/v1/search?name=$encodedCity&count=10');
      final response = await _client.get(url).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>?;

        if (results == null || results.isEmpty) {
          throw CropRecommendationException(
              '"$trimmedCity" was not recognized as a valid city or district. Please check the spelling.');
        }

        // Filter results in India
        final indianResults = results.where((item) {
          final country = item['country']?.toString().toLowerCase() ?? '';
          final countryCode = item['country_code']?.toString().toLowerCase() ?? '';
          return country == 'india' || countryCode == 'in';
        }).toList();

        if (indianResults.isEmpty) {
          throw CropRecommendationException(
              '"$trimmedCity" could not be located in India. Please enter a valid Indian city or district.');
        }

        // Check if any Indian result matches the selected state
        bool matchedState = false;
        String? foundInState;

        for (final item in indianResults) {
          final admin1 = item['admin1']?.toString() ?? '';
          if (admin1.isNotEmpty) {
            foundInState ??= admin1;
            if (_areStatesMatching(admin1, state)) {
              matchedState = true;
              break;
            }
          }
        }

        if (!matchedState) {
          final actualStateInfo = (foundInState != null && foundInState.isNotEmpty)
              ? 'is located in $foundInState'
              : 'does not belong to $state';
          throw CropRecommendationException(
              '"$trimmedCity" $actualStateInfo, not $state. Please select the correct state or enter a district in $state.');
        }
      }
    } on CropRecommendationException {
      rethrow;
    } catch (_) {
      // Fallback if offline or timeout occurs
    }
  }

  /// Generates top 3 tailored crop recommendations based on location, soil type,
  /// start month, live weather API data, and optional attached soil report.
  Future<CropRecommendationResult> generateCropRecommendations({
    required String state,
    required String city,
    required String soilType,
    required String startMonth,
    SoilDataModel? attachedSoilReport,
    String? soilReportName,
  }) async {
    // 1. Validate location existence and state alignment
    await validateLocation(city, state);

    final liveWeather = await _fetchLiveWeatherSummary(city, state);


    final soilDataSummary = attachedSoilReport != null
        ? jsonEncode(attachedSoilReport.rawMap)
        : 'No specific lab report attached. Use general $soilType soil benchmarks for $city, $state.';

    final promptText = '''
You are an expert agronomic scientist, Indian agricultural meteorologist, and farm economist.

Generate top 3 optimal crop recommendations for a farmer with the following location, climate, and soil parameters:
- State: $state
- City/District: $city
- Soil Type: $soilType
- Planned Cultivation Start Month: $startMonth
- Live Weather Data: $liveWeather
- Soil Lab Report Data: $soilDataSummary

CRITICAL INSTRUCTIONS:
- Incorporate Indian agricultural seasons (Kharif, Rabi, Zaid, Southwest/Northeast Monsoon timing for $startMonth) and real agro-climatic conditions of $city, $state.
- Analyze soil N-P-K, pH balance, micronutrient availability, and moisture retention.
- For each crop recommendation, provide:
  1) "recommendedFertilizers": Array of EXACTLY 3 fertilizer names (e.g. ["Urea (Nitrogen)", "DAP (Phosphorus)", "MOP (Potash)"]). ONLY mention 3 fertilizer names, no extra text.
  2) "decisionRationale": A clear, small 2-sentence explanation describing why this crop and fertilizer decision was taken based on soil N-P-K levels, temperature, and seasonal water requirements.
- Return ONLY a valid JSON object matching the schema below. No markdown fences, no extra text.

JSON SCHEMA:
{
  "cropPlans": [
    {
      "cropName": "Clean concise Crop Name without trailing slashes or unclosed brackets (e.g. Chickpea, Bengal Gram, Maize, Wheat, Cotton, Soybean)",

      "cropIcon": "Emoji (e.g. 🌽, 🌾, 🍅, 🌿)",
      "tagline": "Brief high-yield slogan",
      "durationDays": "e.g. 110 - 120 Days",
      "estimatedInvestmentPerAcre": "e.g. ₹24,500",
      "estimatedProfitPerAcre": "e.g. ₹78,000",
      "roiMultiplier": "e.g. 3.2x",
      "investmentBreakdown": {
        "Seeds & Saplings": "₹4,500",
        "Fertilizers & Soil Amendments": "₹6,000",
        "Labour & Field Operations": "₹7,500",
        "Irrigation & Energy": "₹3,500",
        "Pesticides & Crop Protection": "₹3,000"
      },
      "recommendedFertilizers": [
        "Fertilizer Name 1",
        "Fertilizer Name 2",
        "Fertilizer Name 3"
      ],
      "decisionRationale": "Concise 2-sentence explanation of decision based on soil N-P-K data, temperature, and $startMonth seasonal monsoon window.",
      "cultivationSteps": [
        "Step 1 description",
        "Step 2 description",
        "Step 3 description",
        "Step 4 description"
      ],
      "soilSuitabilityReason": "Why this crop thrives in $soilType soil",
      "climateSuitabilityReason": "Why $startMonth in $city is ideal"
    }
  ]
}
''';

    final parsedMap = await _callGeminiApi(promptText);

    final cropPlans = (parsedMap['cropPlans'] as List<dynamic>?)
            ?.map((c) => CropPlanModel.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];

    if (cropPlans.isEmpty) {
      throw CropRecommendationException('Could not extract crop recommendations.');
    }

    return CropRecommendationResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      generatedAt: DateTime.now(),
      state: state,
      city: city,
      soilType: soilType,
      startMonth: startMonth,
      soilReportName: soilReportName,
      liveWeatherSummary: liveWeather,
      cropPlans: cropPlans,
    );
  }

  Future<Map<String, dynamic>> _callGeminiApi(String promptText) async {
    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': promptText}
          ]
        }
      ],
      'generationConfig': {
        'response_mime_type': 'application/json',
        'temperature': 0.2,
        'topP': 0.8,
        'maxOutputTokens': 8192,
      },
    };

    final response = await _client
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
      final errorMsg = _parseError(response.body);
      throw CropRecommendationException('API Error (${response.statusCode}): $errorMsg');
    }

    return _parseResponse(response.body);
  }

  Map<String, dynamic> _parseResponse(String responseBody) {

    try {
      final json = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = json['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw CropRecommendationException('No candidates returned from AI');
      }

      final parts = candidates[0]['content']['parts'] as List<dynamic>?;
      if (parts == null || parts.isEmpty) {
        throw CropRecommendationException('No text parts in response');
      }

      final rawText = (parts[0]['text'] as String?)?.trim() ?? '';
      return _safeDecodeJson(rawText);
    } catch (e) {
      if (e is CropRecommendationException) rethrow;
      throw CropRecommendationException('Failed to parse AI response: $e');
    }
  }

  Map<String, dynamic> _safeDecodeJson(String text) {
    String cleaned = text.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1);
    }

    try {
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      throw CropRecommendationException('Invalid JSON payload: $e');
    }
  }

  String _parseError(String body) {
    try {
      final map = jsonDecode(body) as Map<String, dynamic>;
      return map['error']?['message']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }

  /// Generates a day-by-day precision agronomy timeline for an adopted crop plan.
  Future<List<CultivationTimelineItem>> generateCultivationTimeline({
    required CropPlanModel cropPlan,
    required String location,
    required DateTime startDate,
    SavedSoilReport? soilReport,
  }) async {
    final formattedDate =
        '${startDate.day}/${startDate.month}/${startDate.year}';
    final soilSummary = soilReport == null
        ? 'General regional soil'
        : 'pH: ${soilReport.soilData.ph}, N: ${soilReport.soilData.nitrogenKgHa}, P: ${soilReport.soilData.phosphorusKgHa}, K: ${soilReport.soilData.potassiumKgHa}, Soil: ${soilReport.soilData.soilType}';

    final prompt = '''

You are an expert agronomist in India.
Generate a simple, clear 7-stage cultivation timeline for a farmer growing:
- Crop: ${cropPlan.cropName} (${cropPlan.durationDays})
- Location: $location
- Start Date: $formattedDate
- Soil Test: $soilSummary

INSTRUCTIONS:
1. Provide EXACTLY 7 main chronological stages following Indian crop cycles:
   Stage 1 (Day 1): Land Prep & Seed Selection
   Stage 2 (Day 18): Sowing & Initial Water
   Stage 3 (Day 30): Germination & Early Weeding
   Stage 4 (Day 50): Vegetative Growth & Fertilizer Dose
   Stage 5 (Day 75): Flowering & Pest Control
   Stage 6 (Day 95): Fruit/Pod/Grain Development
   Stage 7 (Day 115): Maturity, Harvest & Market
2. For each step, specify:
   - "dayOffset": Integer day number (1, 18, 30, 50, 75, 95, 115).
   - "title": Concise stage name with day range (e.g. "Land Prep & Seeds (Day 0–15)").
   - "actionIcon": Single Emoji (e.g. 🚜, 🌱, 💧, 🧪, 🌸, 🌿, 🌾).
   - "instructions": 1 simple, clear, actionable sentence that any farmer can easily understand.
3. Return ONLY a valid JSON object matching the schema below. No markdown fences.

JSON SCHEMA:
{
  "timeline": [
    {
      "dayOffset": 1,
      "title": "Land Prep & Seeds (Day 0–15)",
      "actionIcon": "🚜",
      "instructions": "Plough field, add compost manure, select quality seeds, and prepare beds."
    }
  ]
}
''';

    try {
      final jsonMap = await _callGeminiApi(prompt);
      final rawList = jsonMap['timeline'] as List<dynamic>? ?? [];
      final List<CultivationTimelineItem> result = [];

      for (final item in rawList) {
        if (item is Map) {
          result.add(
            CultivationTimelineItem.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }

      if (result.isEmpty) {
        return _fallbackTimeline(cropPlan);
      }

      result.sort((a, b) => a.dayOffset.compareTo(b.dayOffset));
      return result;
    } catch (_) {
      return _fallbackTimeline(cropPlan);
    }
  }

  List<CultivationTimelineItem> _fallbackTimeline(CropPlanModel plan) {
    return [
      CultivationTimelineItem(
        dayOffset: 1,
        title: 'Land Prep & Seeds (Day 0–15)',
        actionIcon: '🚜',
        instructions:
            'Plough field, add compost manure, treat seeds, and prepare beds.',
      ),
      CultivationTimelineItem(
        dayOffset: 18,
        title: 'Sowing & Initial Water (Day 15–25)',
        actionIcon: '🌱',
        instructions:
            'Sow seeds at correct depth and give initial light irrigation.',
      ),
      CultivationTimelineItem(
        dayOffset: 30,
        title: 'Germination & Weed Control (Day 25–45)',
        actionIcon: '💧',
        instructions:
            'Check plant population, fill missing gaps, and clear early weeds.',
      ),
      CultivationTimelineItem(
        dayOffset: 50,
        title: 'Vegetative Growth & Fertilizer (Day 45–70)',
        actionIcon: '🧪',
        instructions:
            'Apply scheduled N-P-K fertilizer dose and irrigate regularly.',
      ),
      CultivationTimelineItem(
        dayOffset: 75,
        title: 'Flowering & Pest Care (Day 70–90)',
        actionIcon: '🌸',
        instructions:
            'Inspect crops for pests, maintain soil moisture, and protect flowers.',
      ),
      CultivationTimelineItem(
        dayOffset: 95,
        title: 'Fruit & Grain Growth (Day 90–110)',
        actionIcon: '🌿',
        instructions:
            'Provide final nutrient support and monitor crop maturity.',
      ),
      CultivationTimelineItem(
        dayOffset: 115,
        title: 'Harvest & Market (Day 110–120+)',
        actionIcon: '🌾',
        instructions:
            'Stop water 7 days before, harvest at maturity, dry, and sell in market.',
      ),
    ];
  }
}


