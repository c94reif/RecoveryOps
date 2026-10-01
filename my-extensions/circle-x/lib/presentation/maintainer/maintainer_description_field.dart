import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/presentation/maintainer/maintainer_review_view_model.dart';

class MaintainerDescriptionField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onDictate;
  final bool isListening;
  final bool enabled;
  final String? message;

  const MaintainerDescriptionField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onDictate,
    required this.isListening,
    this.enabled = true,
    this.message,
  });

  @override
  State<MaintainerDescriptionField> createState() =>
      _MaintainerDescriptionFieldState();
}

class _MaintainerDescriptionFieldState
    extends State<MaintainerDescriptionField> {
  late final controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(MaintainerDescriptionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.text != widget.value) {
      controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: controller,
            enabled: widget.enabled && !widget.isListening,
            onChanged: widget.onChanged,
            minLines: 2,
            maxLines: 5,
            maxLength: MaintainerReviewViewModel.maxDescriptionLength,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Maintainer description',
              hintText: 'What did you find? Type or dictate your notes.',
              alignLabelWithHint: true,
            ),
          ),
          TextButton.icon(
            onPressed: widget.enabled
                ? () {
                    FocusScope.of(context).unfocus();
                    widget.onDictate();
                  }
                : null,
            style: TextButton.styleFrom(
              foregroundColor:
                  widget.isListening ? circleXAmber : serviceableGreen,
              minimumSize: const Size(0, minTouchTarget),
            ),
            icon: Icon(widget.isListening ? Icons.stop : Icons.mic_none),
            label: Text(
                widget.isListening ? 'Stop recording' : 'Dictate description'),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              widget.message ??
                  (widget.isListening
                      ? 'Listening… Tap stop when finished.'
                      : 'Voice input adds to your notes. Edit before submitting.'),
              style: TextStyle(
                color: widget.message != null ? circleXAmber : textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
}
