class AppConstants {
  AppConstants._();

  // Gemini API
  static const String geminiApiKey =
      'AQ.' 'Ab8RN6JBFIQzloMH9MOLd8RJ3XmqKFf0V_dmrrXON2hN72lnjQ';
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const String geminiModel = 'gemini-flash-latest';

  // App
  static const String appName = 'FarmSense';
  static const String appVersion = '1.0.0';

  // Soil prompt — open-ended: extract EVERYTHING visible in the report
  static const String soilAnalysisPrompt = '''
You are an expert soil scientist. Analyze this soil report document carefully.

Your task: Extract ALL soil nutrient values, test parameters, lab details, farmer info, dates, and recommendations visible in this report.

Rules:
- Return ONLY a valid JSON object. No markdown, no code fences, no explanation — just raw JSON.
- Use descriptive snake_case field names for keys.
- Include measurement units in field names or values where helpful.
- For nutrient test tables, extract every single parameter row (parameter, result, unit).
- Keep addresses and legal disclaimers concise so the JSON is compact and complete.
- Include a "report_summary" string field with a brief 1-2 sentence summary of overall soil health.

Return ONLY the JSON object.
''';
}
