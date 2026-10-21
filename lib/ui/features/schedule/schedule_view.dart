import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/medication.dart';
import '../../../data/repositories/medication_repository.dart';
import '../../core/widgets/avatar_badge.dart';

class ScheduleView extends StatefulWidget {
  final MedicationRepository medicationRepository;
  final VoidCallback onDoseLogged;

  const ScheduleView({
    super.key,
    required this.medicationRepository,
    required this.onDoseLogged,
  });

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  List<Medication> _meds = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final meds = await widget.medicationRepository.getTodayMedications();
      setState(() {
        _meds = meds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDose(Medication med) async {
    try {
      await widget.medicationRepository.logDose(med.id);
      widget.onDoseLogged();
      _loadSchedule();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dose recorded for ${med.name} (${med.petName ?? "Pet"})!'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record dose: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final todayFormatted = DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadSchedule, child: const Text('Retry')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily Medication Tracker',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stay on schedule: track doses given to your pets today.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      todayFormatted,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_meds.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  const Text(
                    'No medications scheduled',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'None of your pets currently have active medications. Add a medication to a pet to track its daily doses here!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                // Adaptive grid: 1 col on mobile, 2 cols on tablet/desktop
                final isWide = constraints.maxWidth > 700;
                if (!isWide) {
                  return Column(
                    children: _meds.map((m) => _buildScheduleCard(m, isDark)).toList(),
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: _meds.length,
                  itemBuilder: (ctx, idx) => _buildScheduleCard(_meds[idx], isDark),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Medication med, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isTaken = med.takenTodayCount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTaken
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: isTaken ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              AvatarBadge(
                avatar: med.petAvatar ?? 'dog',
                photoUrl: med.petPhotoUrl,
                baseUrl: widget.medicationRepository.apiService.baseUrl,
                size: 40,
                fontSize: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.petName ?? 'Pet',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      med.petSpecies ?? 'Pet',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isTaken
                      ? const Color(0x2610B981)
                      : const Color(0x26F59E0B),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isTaken ? 'Taken (${med.takenTodayCount}x)' : 'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isTaken ? const Color(0xFF10B981) : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        med.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${med.dosage})',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: primaryColor),
                      ),
                    ],
                  ),
                  Text(
                    '${med.frequency} • ${med.timeOfDay}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTaken ? const Color(0xFF10B981) : primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.check, size: 14),
                label: Text(isTaken ? 'Take Another' : 'Mark Taken'),
                onPressed: () => _handleDose(med),
              ),
            ],
          ),
          if (med.instructions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Notes: ${med.instructions}',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
