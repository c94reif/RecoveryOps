abstract class SpeechRecognitionStrategy {
  Future<void> startListening({required void Function(String text) onResult});

  Future<void> stopListening();

  bool get isListening;
}
