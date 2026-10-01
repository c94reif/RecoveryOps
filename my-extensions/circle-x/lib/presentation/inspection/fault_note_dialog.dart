import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/entities/fault_description.dart';
import 'package:circle_x/domain/services/speech_recognition_strategy.dart';
import 'package:circle_x/domain/services/user_notification_sink.dart';
import 'package:circle_x/presentation/inspection/controllers/fault_dictation_controller.dart';

class FaultNoteDialog extends StatefulWidget {
  final String itemName;
  final String condition;
  final String? initialNote;
  final Future<bool> Function(String note) onSave;
  final SpeechRecognitionStrategy speech;

  const FaultNoteDialog({
    super.key,
    required this.itemName,
    required this.condition,
    required this.initialNote,
    required this.onSave,
    required this.speech,
  });

  @override
  State<FaultNoteDialog> createState() => _FaultNoteDialogState();
}

class _FaultNoteDialogState extends State<FaultNoteDialog>
    implements UserNotificationSink {
  late final controller = TextEditingController(text: widget.initialNote);
  late final FaultDictationController dictation;
  bool saving = false;
  bool saveFailed = false;
  String? dictationMessage;

  @override
  void initState() {
    super.initState();
    dictation = FaultDictationController(
      speech: widget.speech,
      notifications: this,
    )..addListener(refreshDictation);
  }

  void refreshDictation() {
    if (mounted) setState(() {});
  }

  @override
  void enqueue(String message,
      {bool isError = false, bool persistent = false}) {
    if (mounted) setState(() => dictationMessage = message);
  }

  Future<void> toggleDictation() async {
    if (saving) return;
    FocusScope.of(context).unfocus();
    setState(() => dictationMessage = null);
    await dictation.toggle(
      itemId: 'description',
      isCurrent: () => mounted && !saving,
      onResult: (text) async {
        if (text.trim().isEmpty) return;
        final draft = [controller.text.trim(), text.trim()]
            .where((part) => part.isNotEmpty)
            .join(' ')
            .characters;
        final limited = draft.take(maxFaultDescriptionLength).toString();
        controller.value = TextEditingValue(
          text: limited,
          selection: TextSelection.collapsed(offset: limited.length),
        );
        if (draft.length > maxFaultDescriptionLength) {
          enqueue(
              'Description limited to 155 characters. Review before saving.');
        }
      },
    );
  }

  Future<void> save() async {
    if (saving || dictation.isListening) return;
    setState(() {
      saving = true;
      saveFailed = false;
    });
    bool saved;
    try {
      saved = await widget.onSave(controller.text);
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    setState(() {
      saving = false;
      saveFailed = !saved;
    });
    if (saved) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    dictation.removeListener(refreshDictation);
    dictation.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !saving,
      child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        scrollable: true,
        title: const Text('Fault description'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.itemName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(widget.condition),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                enabled: !saving && !dictation.isListening,
                minLines: 3,
                maxLines: 5,
                maxLength: maxFaultDescriptionLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  alignLabelWithHint: true,
                  hintText: 'Describe the location, symptoms or other details.',
                ),
              ),
              TextButton.icon(
                onPressed: saving ? null : toggleDictation,
                icon: Icon(dictation.isListening ? Icons.stop : Icons.mic_none),
                label: Text(dictation.isListening
                    ? 'Stop recording'
                    : 'Dictate description'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, minTouchTarget),
                ),
              ),
              Semantics(
                liveRegion: true,
                child: Text(dictationMessage ??
                    (dictation.isListening
                        ? 'Listening… Tap stop when finished.'
                        : 'Voice input adds to your description. Review before saving.')),
              ),
              if (widget.initialNote?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                const Text('Clear the field to remove this description.'),
              ],
              if (saveFailed) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Could not save the description. Your text is still here; try again.',
                    style: TextStyle(color: circleXAmber),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving || dictation.isListening ? null : save,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, minTouchTarget),
            ),
            child: Text(saving ? 'Saving…' : 'Save description'),
          ),
        ],
      ),
    );
  }
}
