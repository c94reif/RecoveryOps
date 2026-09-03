abstract class SpeechRecognitionStrategy {
  Future<bool> get isAvailable;
  Future<void> startListening({required void Function(String text) onResult});
  Future<void> stopListening();
}
