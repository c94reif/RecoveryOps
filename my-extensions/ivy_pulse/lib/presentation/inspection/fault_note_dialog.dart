import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ivy_pulse/core/theme/app_theme.dart';
import 'package:ivy_pulse/domain/entities/fault_description.dart';

/// Keeps a typed note available for retry if its local save fails.
class FaultNoteDialog extends StatefulWidget {
  final String itemName;
  final String condition;
  final String? initialNote;
  final Future<bool> Function(String note) onSave;

  const FaultNoteDialog({
    super.key,
    required this.itemName,
    required this.condition,
    required this.initialNote,
    required this.onSave,
  });

  @override
  State<FaultNoteDialog> createState() => _FaultNoteDialogState();
}

class _FaultNoteDialogState extends State<FaultNoteDialog> {
  late final controller = TextEditingController(text: widget.initialNote);
  bool saving = false;
  bool saveFailed = false;

  Future<void> save() async {
    if (saving) return;
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
                enabled: !saving,
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
            onPressed: saving ? null : save,
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
