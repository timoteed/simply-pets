import 'package:flutter/material.dart';

enum StatCardType { primary, amber, green }

class StatCard extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final StatCardType type;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.type = StatCardType.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color iconBg;
    Color iconBorder;
    switch (type) {
      case StatCardType.primary:
        iconBg = isDark ? const Color(0x2614B8A6) : const Color(0xFFCCFBF1);
        iconBorder = isDark ? const Color(0xFF14B8A6) : const Color(0xFF0D9488);
        break;
      case StatCardType.amber:
        iconBg = isDark ? const Color(0x26F59E0B) : const Color(0xFFFEF3C7);
        iconBorder = isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
        break;
      case StatCardType.green:
        iconBg = isDark ? const Color(0x2610B981) : const Color(0xFFD1FAE5);
        iconBorder = isDark ? const Color(0xFF10B981) : const Color(0xFF059669);
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
                border: Border.all(color: iconBorder.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Text(
                icon,
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
