import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:circle_x/domain/services/speech_recognition_strategy.dart';
import 'package:circle_x/domain/services/user_notification_sink.dart';

class FaultDictationController extends ChangeNotifier {
  final SpeechRecognitionStrategy speech;
  final UserNotificationSink notifications;
  bool isListening = false;
  String? listeningItemId;
  int _generation = 0;
  bool _disposed = false;

  FaultDictationController({
    required this.speech,
    required this.notifications,
  });

  Future<void> toggle({
    required String itemId,
    required bool Function() isCurrent,
    required Future<void> Function(String text) onResult,
  }) async {
    if (_disposed) return;
    if (isListening && listeningItemId == itemId) {
      await stop();
      return;
    }
    if (isListening) await stop(discardResult: true);
    if (_disposed || !isCurrent()) return;

    final generation = ++_generation;
    isListening = true;
    listeningItemId = itemId;
    notifyListeners();

    try {
      await speech.startListening(onResult: (text) async {
        if (_disposed ||
            _generation != generation ||
            !isCurrent() ||
            listeningItemId != itemId) {
          return;
        }
        _finishListening();
        await onResult(text);
      });
      if (!_disposed &&
          _generation == generation &&
          isListening &&
          !speech.isListening) {
        _reportUnavailable();
      }
    } catch (error) {
      debugPrint('[CircleX] dictation failed: $error');
      if (_disposed || _generation != generation) return;
      _reportUnavailable();
    }
  }

  Future<void> stop({bool discardResult = false}) async {
    if (_disposed) return;
    final generation = discardResult ? ++_generation : _generation;
    if (discardResult) _finishListening();
    try {
      await speech.stopListening();
    } catch (error) {
      debugPrint('[CircleX] stop dictation failed: $error');
    } finally {
      if (!_disposed && _generation == generation) _finishListening();
    }
  }

  void _finishListening() {
    isListening = false;
    listeningItemId = null;
    notifyListeners();
  }

  void _reportUnavailable() {
    notifications
        .enqueue('Dictation unavailable — you can still type a description.');
    _finishListening();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    if (isListening) {
      unawaited(speech.stopListening().catchError((Object error) {
        debugPrint('[CircleX] dictation disposal failed: $error');
      }));
    }
    super.dispose();
  }
}
