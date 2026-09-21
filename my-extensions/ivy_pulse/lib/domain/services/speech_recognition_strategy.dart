/// Dictation for fault notes — a Soldier in gloves under a vehicle should not
/// have to type.
abstract class SpeechRecognitionStrategy {
  Future<void> startListening({required void Function(String text) onResult});

  Future<void> stopListening();

  bool get isListening;
}
