import 'package:flutter/material.dart';

class CacNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  final Color? textColor;

  const CacNote({
    super.key,
    required this.icon,
    required this.text,
    required this.color,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor ?? color,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      );
}
