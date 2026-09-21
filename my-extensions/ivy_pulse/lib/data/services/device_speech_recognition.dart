import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:ivy_pulse/domain/services/speech_recognition_strategy.dart';

class DeviceSpeechRecognition implements SpeechRecognitionStrategy {
  final stt.SpeechToText speech = stt.SpeechToText();
  bool initialized = false;
  bool listening = false;
  void Function(String text)? pendingOnResult;

  Future<void> ensureInitialized() async {
    if (initialized) return;
    try {
      initialized = await speech.initialize(
        // On some hosts the plugin never fires a final result — it just goes
        // quiet — so the status transition is the second way out. Either
        // path fires the callback once, then clears it.
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            listening = false;
            final lastWords = speech.lastRecognizedWords;
            if (lastWords.isNotEmpty && pendingOnResult != null) {
              final callback = pendingOnResult!;
              pendingOnResult = null;
              callback(lastWords);
            }
          }
        },
      );
    } catch (e) {
      // No microphone permission, or no speech engine behind the WebView —
      // dictation is optional, the operator can still type the note.
      debugPrint('[IvyPulse] Speech initialize error: $e');
      initialized = false;
    }
  }

  @override
  bool get isListening => listening;

  @override
  Future<void> startListening({
    required void Function(String text) onResult,
  }) async {
    await ensureInitialized();
    if (!initialized) return;

    pendingOnResult = onResult;

    try {
      listening = true;
      await speech.listen(
        onResult: (result) {
          if (result.finalResult && pendingOnResult != null) {
            listening = false;
            final callback = pendingOnResult!;
            pendingOnResult = null;
            callback(result.recognizedWords);
          }
        },
      );
    } catch (e) {
      debugPrint('[IvyPulse] Speech listen error: $e');
      listening = false;
      pendingOnResult = null;
    }
  }

  @override
  Future<void> stopListening() async {
    listening = false;
    try {
      await speech.stop();
    } catch (e) {
      debugPrint('[IvyPulse] Speech stop error: $e');
    }
  }
}
