import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:circle_x/domain/services/speech_recognition_strategy.dart';

class DeviceSpeechRecognition implements SpeechRecognitionStrategy {
  final stt.SpeechToText speech = stt.SpeechToText();
  bool initialized = false;
  bool listening = false;
  void Function(String text)? pendingOnResult;

  Future<void> ensureInitialized() async {
    if (initialized) return;
    try {
      initialized = await speech.initialize(
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
    } catch (error) {
      debugPrint('[CircleX] Speech initialize error: $error');
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
    } catch (error) {
      debugPrint('[CircleX] Speech listen error: $error');
      listening = false;
      pendingOnResult = null;
    }
  }

  @override
  Future<void> stopListening() async {
    listening = false;
    try {
      await speech.stop();
    } catch (error) {
      debugPrint('[CircleX] Speech stop error: $error');
    }
  }
}
