import 'package:flutter/material.dart';
import 'package:circle_x/core/theme/app_theme.dart';
import 'package:circle_x/domain/profile/entities/profile.dart';
import 'package:circle_x/presentation/common/widgets/custom_text_field.dart';
import 'package:circle_x/presentation/common/widgets/uic_text_field.dart';
import 'package:circle_x/presentation/profile/profile_view_model.dart';

class FollowedUnitsCard extends StatelessWidget {
  final ProfileViewModel viewModel;

  const FollowedUnitsCard({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgDark,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Followed units',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Include these UICs in your unit reports. Your default UIC stays '
              'selected for new inspections. Unit names are saved only on this device.',
              style:
                  TextStyle(color: textSecondary, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 12),
            for (final unit in viewModel.followedUnits)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(unit.name.isEmpty ? unit.uic : unit.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          if (unit.name.isNotEmpty)
                            Text(unit.uic,
                                style: const TextStyle(color: textSecondary)),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Manage ${unit.uic}',
                      enabled: !viewModel.isSaving,
                      onSelected: (action) {
                        if (action == 'edit') {
                          _edit(context, unit: unit);
                        } else {
                          viewModel.removeFollowedUnit(unit.uic);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit unit')),
                        PopupMenuItem(
                            value: 'remove', child: Text('Remove unit')),
                      ],
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: viewModel.isSaving || !viewModel.hasExistingProfile
                    ? null
                    : () => _edit(context),
                icon: const Icon(Icons.add),
                label: const Text('Follow another UIC'),
              ),
            ),
            if (!viewModel.hasExistingProfile)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Save your default UIC to follow other units.',
                    style: TextStyle(color: textSecondary, fontSize: 13)),
              ),
          ],
        ),
      );

  void _edit(BuildContext context, {FollowedUnit? unit}) {
    FocusScope.of(context).unfocus();
    showDialog<void>(
      context: context,
      builder: (_) => _FollowedUnitDialog(viewModel: viewModel, unit: unit),
    );
  }
}

class _FollowedUnitDialog extends StatefulWidget {
  final ProfileViewModel viewModel;
  final FollowedUnit? unit;

  const _FollowedUnitDialog({required this.viewModel, this.unit});

  @override
  State<_FollowedUnitDialog> createState() => _FollowedUnitDialogState();
}

class _FollowedUnitDialogState extends State<_FollowedUnitDialog> {
  late final uic = TextEditingController(text: widget.unit?.uic ?? '');
  late final name = TextEditingController(text: widget.unit?.name ?? '');
  bool saving = false;
  String? error;

  @override
  void dispose() {
    uic.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final validation = widget.viewModel
        .followedUnitError(uic.text, editingUic: widget.unit?.uic);
    if (validation != null) {
      setState(() => error = validation);
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final saved = widget.unit == null
        ? await widget.viewModel.addFollowedUnit(uic.text, name: name.text)
        : await widget.viewModel
            .updateFollowedUnit(widget.unit!.uic, uic.text, name: name.text);
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        saving = false;
        error = widget.viewModel.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !saving,
        child: AlertDialog(
          scrollable: true,
          title: Text(
              widget.unit == null ? 'Follow a unit' : 'Edit followed unit'),
          content: AbsorbPointer(
            absorbing: saving,
            child: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UicTextField(controller: uic, label: 'UIC to follow'),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: name,
                    label: 'Unit name (optional)',
                    hint: 'Alpha Company',
                    helperText: 'A local label for this device',
                    textCapitalization: TextCapitalization.words,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'Saving...' : 'Save unit'),
            ),
          ],
        ),
      );
}
