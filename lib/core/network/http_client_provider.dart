import 'package:http/http.dart' as http;

/// A single shared [http.Client] used by all service singletons.
///
/// Using one shared client across [GeminiService], [MandiService], and
/// [AgriculturalMonitoringService] reduces connection-pool overhead and avoids
/// leaking separate client instances.  The client lives for the entire app
/// lifetime — the OS reclaims connections on process exit.
class AppHttpClient {
  AppHttpClient._();

  /// The single shared [http.Client] instance for the entire app.
  static final http.Client instance = http.Client();
}
