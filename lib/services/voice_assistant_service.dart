import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Production-grade Voice Assistant Service providing Speech-to-Text (STT) voice input
/// and Text-to-Speech (TTS) natural audio playback for Megha AI.
class VoiceAssistantService {
  static final VoiceAssistantService instance = VoiceAssistantService._();

  VoiceAssistantService._() {
    _initTts();
  }

  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();

  bool _isSttInitialized = false;
  bool _isTtsInitialized = false;

  /// Notifier for real-time speech-to-text active listening state
  final ValueNotifier<bool> isListening = ValueNotifier<bool>(false);

  /// Notifier for real-time speech-to-text recognized live text
  final ValueNotifier<String> recognizedText = ValueNotifier<String>('');

  /// Notifier tracking the ID/content of the currently speaking message
  final ValueNotifier<String?> currentlySpeakingId = ValueNotifier<String?>(null);

  // ── 1. Text-To-Speech (TTS) Initialization & Controls ───────────────────────

  Future<void> _initTts() async {
    if (_isTtsInitialized) return;
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.48); // Natural, clear conversational cadence
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setCompletionHandler(() {
        currentlySpeakingId.value = null;
      });

      _tts.setCancelHandler(() {
        currentlySpeakingId.value = null;
      });

      _tts.setErrorHandler((dynamic msg) {
        currentlySpeakingId.value = null;
      });

      _isTtsInitialized = true;
    } catch (e) {
      debugPrint('[VoiceAssistantService] TTS Init Error: $e');
    }
  }

  /// Speaks the provided text aloud. If [messageId] is passed, it tracks playback state.
  Future<void> speak(String text, {String? messageId}) async {
    try {
      await _initTts();

      // If already speaking this message, toggle stop
      if (currentlySpeakingId.value == messageId && messageId != null) {
        await stopSpeaking();
        return;
      }

      // Stop any existing speech first
      await _tts.stop();

      final naturalText = sanitizeForSpeech(text);
      if (naturalText.trim().isEmpty) return;

      currentlySpeakingId.value = messageId;
      await _tts.speak(naturalText);
    } catch (e) {
      debugPrint('[VoiceAssistantService] Speak error: $e');
      currentlySpeakingId.value = null;
    }
  }

  /// Stops any active speech playback
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('[VoiceAssistantService] Stop speaking error: $e');
    } finally {
      currentlySpeakingId.value = null;
    }
  }

  bool _isManualListeningActive = false;
  final List<String> _finalizedPhrases = [];
  String _currentLivePhrase = '';
  Timer? _restartTimer;
  Function(String text)? _currentResultCallback;
  Function(bool isListening)? _currentStatusCallback;

  // ── 2. Speech-To-Text (STT) Voice Input ─────────────────────────────────────

  /// Initializes speech recognition engine and checks permissions
  Future<bool> initSpeech() async {
    if (_isSttInitialized) return true;

    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        debugPrint('[VoiceAssistantService] Microphone permission denied');
        return false;
      }

      _isSttInitialized = await _stt.initialize(
        onError: (SpeechRecognitionError error) {
          debugPrint('[VoiceAssistantService] STT Error: ${error.errorMsg}');
          _commitLivePhrase();
          if (_isManualListeningActive) {
            _scheduleSessionRestart();
          }
        },
        onStatus: (String status) {
          debugPrint('[VoiceAssistantService] STT Status: $status');
          if (status == 'notListening' || status == 'done') {
            _commitLivePhrase();
            if (_isManualListeningActive) {
              _scheduleSessionRestart();
            } else {
              isListening.value = false;
              _currentStatusCallback?.call(false);
            }
          } else if (status == 'listening') {
            isListening.value = true;
            _currentStatusCallback?.call(true);
          }
        },
      );
      return _isSttInitialized;
    } catch (e) {
      debugPrint('[VoiceAssistantService] STT initialization failed: $e');
      _isSttInitialized = false;
      return false;
    }
  }

  bool isContinuation(String prev, String next) {
    final p = prev.toLowerCase().trim();
    final n = next.toLowerCase().trim();
    if (p.isEmpty) return true;
    if (n.isEmpty) return false;

    // 1. Direct prefix match: "what" -> "what is"
    if (n.startsWith(p)) return true;

    // 2. Word-level prefix match: first word identical
    final prevWords = p.split(RegExp(r'\s+'));
    final nextWords = n.split(RegExp(r'\s+'));
    if (prevWords.isNotEmpty && nextWords.isNotEmpty) {
      if (prevWords.first == nextWords.first) {
        return true;
      }
    }

    return false;
  }

  void _commitLivePhrase() {
    final phrase = _currentLivePhrase.trim();
    if (phrase.isNotEmpty) {
      if (_finalizedPhrases.isEmpty || _finalizedPhrases.last != phrase) {
        _finalizedPhrases.add(phrase);
      }
      _currentLivePhrase = '';
      _notifyCombinedText();
    }
  }

  String get _combinedText {
    final all = <String>[];
    for (final phrase in _finalizedPhrases) {
      final clean = phrase.trim();
      if (clean.isNotEmpty) {
        all.add(clean);
      }
    }
    final live = _currentLivePhrase.trim();
    if (live.isNotEmpty) {
      all.add(live);
    }
    return all.join(' ').trim();
  }

  void _notifyCombinedText() {
    final full = _combinedText;
    recognizedText.value = full;
    _currentResultCallback?.call(full);
  }

  void _scheduleSessionRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 250), () {
      if (_isManualListeningActive) {
        _listenSession();
      }
    });
  }

  /// Starts continuous listening to microphone speech until stopped manually
  Future<bool> startListening({
    required Function(String text) onResult,
    Function(bool isListening)? onStatusChange,
  }) async {
    final ready = await initSpeech();
    if (!ready) return false;

    // Stop TTS if speaking so mic doesn't record speaker audio
    await stopSpeaking();

    _restartTimer?.cancel();
    _isManualListeningActive = true;
    _finalizedPhrases.clear();
    _currentLivePhrase = '';
    _currentResultCallback = onResult;
    _currentStatusCallback = onStatusChange;
    recognizedText.value = '';
    isListening.value = true;
    onStatusChange?.call(true);

    return _listenSession();
  }

  Future<bool> _listenSession() async {
    if (!_isManualListeningActive) return false;
    try {
      _commitLivePhrase();
      if (_stt.isListening) {
        await _stt.stop();
      }

      await _stt.listen(
        onResult: (SpeechRecognitionResult result) {
          final chunk = result.recognizedWords.trim();
          if (chunk.isNotEmpty) {
            // Check if chunk is a continuation or a new phrase after pause
            if (!isContinuation(_currentLivePhrase, chunk)) {
              _commitLivePhrase();
            }

            _currentLivePhrase = chunk;
            _notifyCombinedText();

            if (result.finalResult) {
              _commitLivePhrase();
            }
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(minutes: 10),
          pauseFor: const Duration(seconds: 15),
          localeId: "en_US",
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[VoiceAssistantService] Start listening error: $e');
      _commitLivePhrase();
      if (_isManualListeningActive) {
        _scheduleSessionRestart();
      }
      return false;
    }
  }

  /// Stops active microphone listening
  Future<void> stopListening() async {
    _isManualListeningActive = false;
    _restartTimer?.cancel();
    _commitLivePhrase();
    final finalText = _combinedText;
    _currentResultCallback = null;
    _currentStatusCallback = null;
    try {
      await _stt.stop();
    } catch (e) {
      debugPrint('[VoiceAssistantService] Stop listening error: $e');
    } finally {
      isListening.value = false;
      recognizedText.value = finalText;
    }
  }

  // ── 3. Natural Speech Text Sanitizer ────────────────────────────────────────

  /// Cleans raw Markdown, formulas, citation badges, and punctuation artifacts
  /// into smooth, natural human speech pronunciation.
  String sanitizeForSpeech(String markdown) {
    String text = markdown;

    // Remove multi-line code blocks
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');

    // Remove markdown citations and source tags with leading whitespace
    text = text.replaceAll(
      RegExp(r'\s*\[\s*(?:cited:)?\s*[^\]\n]*?(?:page\s*\d+|source\s*\d+|[a-zA-Z0-9_\-.]+\.pdf)[^\]\n]*?\]',
          caseSensitive: false),
      '',
    );
    text = text.replaceAll(
      RegExp(r'\s*\(\s*(?:page\s*\d+|source\s*\d+)\s*\)', caseSensitive: false),
      '',
    );

    // Convert formula fractions e.g. [ (A - B) / B ] or (A - B) / B
    text = text.replaceAllMapped(
      RegExp(r'\[\s*\(?([^/\]\n]+?)\)?\s*/\s*\(?([^/\]\n]+?)\)?\s*\]'),
      (m) => '${m.group(1)?.trim()} divided by ${m.group(2)?.trim()}',
    );
    text = text.replaceAllMapped(
      RegExp(r'\(\s*([^/\n]+?)\s*/\s*([^/\n]+?)\s*\)'),
      (m) => '${m.group(1)?.trim()} divided by ${m.group(2)?.trim()}',
    );

    // Convert common math operators to spoken English words
    text = text.replaceAll('×', ' times ');
    text = text.replaceAll('·', ' times ');
    text = text.replaceAll('±', ' plus or minus ');
    text = text.replaceAll('≈', ' approximately ');
    text = text.replaceAll('≠', ' does not equal ');
    text = text.replaceAll('≥', ' is greater than or equal to ');
    text = text.replaceAll('≤', ' is less than or equal to ');
    text = text.replaceAll('%', ' percent');
    text = text.replaceAll('°C', ' degrees celsius');
    text = text.replaceAll('°', ' degrees');

    // Strip markdown formatting tokens (asterisks, underscores, hashes, backticks, brackets)
    text = text.replaceAll(RegExp(r'[*_~#>`\[\]]'), '');

    // Clean bullet dashes at start of lines
    text = text.replaceAll(RegExp(r'(?:^|\n)\s*-\s*'), '\n');

    // Clean emojis & special symbols for clean audio
    text = text.replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '');

    // Normalize spacing and fix punctuation spacing
    text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
    text = text.replaceAll(RegExp(r'\s+([.,!?;:])'), r'$1');
    text = text.replaceAll(RegExp(r'\n+'), '. ');
    return text.trim();
  }

  /// Disposes active resources and listeners
  void dispose() {
    _tts.stop();
    _stt.stop();
  }
}
