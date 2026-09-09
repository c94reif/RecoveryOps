import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:recovery_ops/domain/services/speech_recognition_strategy.dart';

class DeviceSpeechRecognition implements SpeechRecognitionStrategy {
  final stt.SpeechToText speech = stt.SpeechToText();
  bool initialized = false;
  void Function(String text)? pendingOnResult;

  Future<void> ensureInitialized() async {
    if (!initialized) {
      initialized = await speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            final lastWords = speech.lastRecognizedWords;
            if (lastWords.isNotEmpty && pendingOnResult != null) {
              final callback = pendingOnResult!;
              pendingOnResult = null;
              callback(lastWords);
            }
          }
        },
      );
    }
  }

  @override
  Future<bool> get isAvailable async {
    await ensureInitialized();
    return initialized;
  }

  @override
  Future<void> startListening({
    required void Function(String text) onResult,
  }) async {
    await ensureInitialized();
    if (!initialized) return;

    pendingOnResult = onResult;

    await speech.listen(
      onResult: (result) {
        if (result.finalResult && pendingOnResult != null) {
          final callback = pendingOnResult!;
          pendingOnResult = null;
          callback(result.recognizedWords);
        }
      },
    );
  }

  @override
  Future<void> stopListening() async {
    await speech.stop();
  }
}
