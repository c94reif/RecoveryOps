import 'package:flutter/material.dart';

import '../theme/lattice_theme_extension.dart';
import '../tokens/lattice_spacing.dart';

/// 48px panel header with optional back button, centered-left title, and
/// close (X) button.
///
/// Theme-aware — background, border, and icon colors adapt to the active theme.
class LatticePanelHeader extends StatelessWidget {
  const LatticePanelHeader({
    super.key,
    required this.title,
    this.onBack,
    required this.onClose,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.lattice.colors;
    return Container(
      height: LatticeSpacing.touchTarget,
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        children: [
          if (onBack != null)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onBack,
                child: SizedBox(
                  width: LatticeSpacing.touchTarget,
                  height: LatticeSpacing.touchTarget,
                  child: Center(
                    child: Icon(
                      Icons.arrow_back,
                      color: colors.textPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: SizedBox(
                width: LatticeSpacing.touchTarget,
                height: LatticeSpacing.touchTarget,
                child: Center(
                  child: Icon(
                    Icons.close,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
