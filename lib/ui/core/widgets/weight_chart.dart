import 'package:flutter/material.dart';
import '../../../data/models/weight_log.dart';

class WeightChartWidget extends StatefulWidget {
  final List<WeightLog> logs;
  final String unit;

  const WeightChartWidget({
    super.key,
    required this.logs,
    this.unit = 'lbs',
  });

  @override
  State<WeightChartWidget> createState() => _WeightChartWidgetState();
}

class _WeightChartWidgetState extends State<WeightChartWidget> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.logs.isEmpty) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        child: Text(
          'No weight logs recorded yet',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
      );
    }

    final sortedLogs = List<WeightLog>.from(widget.logs)
      ..sort((a, b) => a.loggedDate.compareTo(b.loggedDate));

    double minW = sortedLogs.first.weight;
    double maxW = sortedLogs.first.weight;
    for (final l in sortedLogs) {
      if (l.weight < minW) minW = l.weight;
      if (l.weight > maxW) maxW = l.weight;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatPill('Min', '$minW ${widget.unit}', const Color(0xFFF59E0B)),
            _buildStatPill('Latest', '${sortedLogs.last.weight} ${widget.unit}', primaryColor),
            _buildStatPill('Max', '$maxW ${widget.unit}', const Color(0xFF10B981)),
          ],
        ),
        const SizedBox(height: 16),
        // Interactive Chart
        SizedBox(
          height: 190,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanDown: (details) => _handleTouch(details.localPosition, constraints.maxWidth, sortedLogs.length),
                onPanUpdate: (details) => _handleTouch(details.localPosition, constraints.maxWidth, sortedLogs.length),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 190),
                  painter: _ChartPainter(
                    logs: sortedLogs,
                    minWeight: minW,
                    maxWeight: maxW,
                    primaryColor: primaryColor,
                    isDark: isDark,
                    selectedIndex: _selectedIndex,
                  ),
                ),
              );
            },
          ),
        ),
        if (_selectedIndex != null && _selectedIndex! < sortedLogs.length) ...[
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                '${sortedLogs[_selectedIndex!].loggedDate}: ${sortedLogs[_selectedIndex!].weight} ${widget.unit}${sortedLogs[_selectedIndex!].notes.isNotEmpty ? " • ${sortedLogs[_selectedIndex!].notes}" : ""}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _handleTouch(Offset localPos, double width, int totalPoints) {
    if (totalPoints <= 1) {
      setState(() => _selectedIndex = 0);
      return;
    }
    const paddingLeft = 36.0;
    const paddingRight = 24.0;
    final usableWidth = width - paddingLeft - paddingRight;
    final touchX = (localPos.dx - paddingLeft).clamp(0.0, usableWidth);
    final ratio = touchX / usableWidth;
    final index = (ratio * (totalPoints - 1)).round().clamp(0, totalPoints - 1);
    setState(() => _selectedIndex = index);
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: color),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<WeightLog> logs;
  final double minWeight;
  final double maxWeight;
  final Color primaryColor;
  final bool isDark;
  final int? selectedIndex;

  _ChartPainter({
    required this.logs,
    required this.minWeight,
    required this.maxWeight,
    required this.primaryColor,
    required this.isDark,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const paddingLeft = 36.0;
    const paddingRight = 24.0;
    const paddingTop = 20.0;
    const paddingBottom = 30.0;

    final usableWidth = size.width - paddingLeft - paddingRight;
    final usableHeight = size.height - paddingTop - paddingBottom;

    final gridPaint = Paint()
      ..color = (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
      ..strokeWidth = 1;

    final textStyle = TextStyle(
      fontSize: 10,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    );

    // Draw horizontal grid lines (3 lines)
    final range = (maxWeight - minWeight).abs();
    final effectiveRange = range < 0.1 ? 1.0 : range;

    for (int i = 0; i <= 2; i++) {
      final y = paddingTop + (usableHeight * (i / 2));
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );

      final val = (maxWeight - (effectiveRange * (i / 2))).toStringAsFixed(1);
      final tp = TextPainter(
        text: TextSpan(text: val, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(paddingLeft - tp.width - 6, y - tp.height / 2));
    }

    if (logs.length == 1) {
      final x = paddingLeft + (usableWidth / 2);
      final y = paddingTop + (usableHeight / 2);
      canvas.drawCircle(Offset(x, y), 6, Paint()..color = primaryColor);
      return;
    }

    // Compute coordinate points
    final points = <Offset>[];
    for (int i = 0; i < logs.length; i++) {
      final x = paddingLeft + (usableWidth * (i / (logs.length - 1)));
      final normalized = (logs[i].weight - minWeight) / effectiveRange;
      final y = paddingTop + usableHeight - (normalized * usableHeight);
      points.add(Offset(x, y));
    }

    // Fill path
    final fillPath = Path();
    fillPath.moveTo(points.first.dx, size.height - paddingBottom);
    fillPath.lineTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      fillPath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(points.last.dx, size.height - paddingBottom);
    fillPath.close();

    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        primaryColor.withValues(alpha: 0.35),
        primaryColor.withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(
        Rect.fromLTWH(paddingLeft, paddingTop, usableWidth, usableHeight),
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final strokePath = Path();
    strokePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      strokePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final strokePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(strokePath, strokePaint);

    // Draw points & labels
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isSelected = selectedIndex == i;

      canvas.drawCircle(
        pt,
        isSelected ? 6 : 4,
        Paint()..color = isDark ? const Color(0xFF1E293B) : Colors.white,
      );
      canvas.drawCircle(
        pt,
        isSelected ? 4.5 : 2.5,
        Paint()..color = primaryColor,
      );

      // Date labels on axis for first, middle, last
      if (i == 0 || i == points.length - 1 || (points.length > 2 && i == (points.length ~/ 2))) {
        final dStr = logs[i].loggedDate;
        final shortDate = dStr.length >= 10 ? dStr.substring(5) : dStr;
        final dtp = TextPainter(
          text: TextSpan(text: shortDate, style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        dtp.paint(canvas, Offset(pt.dx - dtp.width / 2, size.height - paddingBottom + 8));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.logs != logs ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isDark != isDark;
  }
}
