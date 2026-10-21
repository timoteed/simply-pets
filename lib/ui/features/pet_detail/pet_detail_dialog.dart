import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/medication.dart';
import '../../../data/models/pet.dart';
import '../../../data/models/weight_log.dart';
import '../../../data/repositories/medication_repository.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../../data/repositories/weight_repository.dart';
import '../../core/widgets/avatar_badge.dart';
import '../../core/widgets/care_sheet_dialog.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/weight_chart.dart';
import '../medication_form/medication_form_dialog.dart';
import '../pet_form/pet_form_dialog.dart';
import '../weight_form/weight_form_dialog.dart';

class PetDetailDialog extends StatefulWidget {
  final int petId;
  final PetRepository petRepository;
  final MedicationRepository medicationRepository;
  final WeightRepository weightRepository;
  final VoidCallback onPetUpdated;

  const PetDetailDialog({
    super.key,
    required this.petId,
    required this.petRepository,
    required this.medicationRepository,
    required this.weightRepository,
    required this.onPetUpdated,
  });

  static Future<void> show({
    required BuildContext context,
    required int petId,
    required PetRepository petRepository,
    required MedicationRepository medicationRepository,
    required WeightRepository weightRepository,
    required VoidCallback onPetUpdated,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => PetDetailDialog(
        petId: petId,
        petRepository: petRepository,
        medicationRepository: medicationRepository,
        weightRepository: weightRepository,
        onPetUpdated: onPetUpdated,
      ),
    );
  }

  @override
  State<PetDetailDialog> createState() => _PetDetailDialogState();
}

class _PetDetailDialogState extends State<PetDetailDialog> {
  Pet? _pet;
  bool _isLoading = true;
  String? _error;
  int _activeTabIndex = 0; // 0: Meds, 1: Weight, 2: Care Sheet

  @override
  void initState() {
    super.initState();
    _loadPet();
  }

  Future<void> _loadPet() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pet = await widget.petRepository.getPetById(widget.petId);
      setState(() {
        _pet = pet;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _quickChangePhoto() async {
    final pet = _pet;
    if (pet == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        await widget.petRepository.uploadPetPhoto(pet.id, bytes, picked.name);
        await _loadPet();
        widget.onPetUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update photo: $e')),
        );
      }
    }
  }

  Future<void> _handleDoseLog(Medication med) async {
    try {
      await widget.medicationRepository.logDose(med.id);
      widget.onPetUpdated();
      _loadPet();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dose recorded for ${med.name}!'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF10B981),
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

  Future<void> _deleteMedication(Medication med) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete Medication',
      message: 'Are you sure you want to delete ${med.name}?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed) {
      try {
        await widget.medicationRepository.deleteMedication(med.id);
        widget.onPetUpdated();
        _loadPet();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteWeightLog(WeightLog log) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete Weight Log',
      message: 'Are you sure you want to remove this ${log.weight} ${log.weightUnit} entry on ${log.loggedDate}?',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed) {
      try {
        await widget.weightRepository.deleteWeightLog(log.id);
        widget.onPetUpdated();
        _loadPet();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 780),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Error loading pet: $_error'),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _loadPet, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _buildContent(context, isDark),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    final pet = _pet!;
    final activeMeds = pet.medications.where((m) => m.isActive).toList();
    final inactiveMeds = pet.medications.where((m) => !m.isActive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _quickChangePhoto,
              child: Tooltip(
                message: 'Click to upload or change pet photo',
                child: Stack(
                  children: [
                    AvatarBadge(
                      avatar: pet.avatar,
                      photoUrl: pet.photoUrl,
                      baseUrl: widget.petRepository.apiService.baseUrl,
                      size: 56,
                      fontSize: 28,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        pet.name,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          pet.species,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${pet.breed.isNotEmpty ? "${pet.breed} • " : ""}${pet.gender} • ${pet.weight} ${pet.weightUnit}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('Print Care Sheet'),
              onPressed: () => CareSheetDialog.show(context, pet),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Edit Profile',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                PetFormDialog.show(
                  context: context,
                  pet: pet,
                  petRepository: widget.petRepository,
                  onSaved: () {
                    widget.onPetUpdated();
                    _loadPet();
                  },
                  onDeleted: () {
                    widget.onPetUpdated();
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const Divider(height: 20),

        // Tabs Row
        Row(
          children: [
            _buildTabChip(
              index: 0,
              icon: '💊',
              label: 'Medications',
              count: pet.medications.length,
            ),
            const SizedBox(width: 8),
            _buildTabChip(
              index: 1,
              icon: '📈',
              label: 'Weight Tracker',
              count: pet.weightHistory.length,
            ),
            const SizedBox(width: 8),
            _buildTabChip(
              index: 2,
              icon: '📋',
              label: 'Care Sheet & Notes',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tab views
        Expanded(
          child: IndexedStack(
            index: _activeTabIndex,
            children: [
              _buildMedicationsTab(context, activeMeds, inactiveMeds, isDark),
              _buildWeightTab(context, pet, isDark),
              _buildCareSheetTab(context, pet, isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabChip({
    required int index,
    required String icon,
    required String label,
    int? count,
  }) {
    final isSelected = _activeTabIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationsTab(
    BuildContext context,
    List<Medication> activeMeds,
    List<Medication> inactiveMeds,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Active Prescriptions (${activeMeds.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Medication'),
              onPressed: () {
                MedicationFormDialog.show(
                  context: context,
                  petId: widget.petId,
                  medicationRepository: widget.medicationRepository,
                  onSaved: () {
                    widget.onPetUpdated();
                    _loadPet();
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (activeMeds.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'No active medications for this pet. Click "+ Add Medication" above to record prescriptions!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    ),
                  )
                else
                  ...activeMeds.map((med) => _buildMedicationItem(context, med, isDark)),

                if (inactiveMeds.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    'Historical / Inactive Prescriptions (${inactiveMeds.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 10),
                  ...inactiveMeds.map((med) => _buildMedicationItem(context, med, isDark)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedicationItem(BuildContext context, Medication med, bool isDark) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: med.isActive ? primaryColor.withValues(alpha: 0.12) : const Color(0xFF64748B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('💊', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      med.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        med.dosage,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryColor),
                      ),
                    ),
                    if (!med.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF64748B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Inactive',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${med.frequency} • ${med.timeOfDay}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                if (med.instructions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Notes: ${med.instructions}',
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
                if (med.prescribingVet.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Prescribed by: ${med.prescribingVet}',
                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  ),
                ],
                if (med.isActive) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: med.takenTodayCount > 0
                              ? const Color(0x2610B981)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          med.takenTodayCount > 0
                              ? '✅ Given today (${med.takenTodayCount}x)'
                              : '⏳ Dose not given yet today',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: med.takenTodayCount > 0
                                ? const Color(0xFF10B981)
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        icon: const Icon(Icons.check, size: 14),
                        label: const Text('Mark Dose Taken'),
                        onPressed: () => _handleDoseLog(med),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit',
            onPressed: () {
              MedicationFormDialog.show(
                context: context,
                petId: widget.petId,
                medication: med,
                medicationRepository: widget.medicationRepository,
                onSaved: () {
                  widget.onPetUpdated();
                  _loadPet();
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
            tooltip: 'Delete',
            onPressed: () => _deleteMedication(med),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightTab(BuildContext context, Pet pet, bool isDark) {
    final logs = List<WeightLog>.from(pet.weightHistory)
      ..sort((a, b) => b.loggedDate.compareTo(a.loggedDate)); // newest first for table

    double? delta;
    if (logs.length >= 2) {
      delta = double.parse((logs[0].weight - logs[1].weight).toStringAsFixed(1));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '${pet.weight} ${pet.weightUnit}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  if (delta != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: delta >= 0
                            ? const Color(0x2610B981)
                            : const Color(0x26EF4444),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        delta >= 0 ? '+$delta ${pet.weightUnit}' : '$delta ${pet.weightUnit}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: delta >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Record Weight'),
                onPressed: () {
                  WeightFormDialog.show(
                    context: context,
                    petId: pet.id,
                    defaultUnit: pet.weightUnit,
                    weightRepository: widget.weightRepository,
                    onSaved: () {
                      widget.onPetUpdated();
                      _loadPet();
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Chart
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: WeightChartWidget(logs: pet.weightHistory, unit: pet.weightUnit),
          ),
          const SizedBox(height: 18),

          // Log History Table
          const Text(
            'Weigh-in History',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),

          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No historical weight records.', style: TextStyle(color: Color(0xFF94A3B8))),
            )
          else
            ...logs.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    Text(
                      entry.loggedDate,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${entry.weight} ${entry.weightUnit}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    if (entry.notes.isNotEmpty) ...[
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          entry.notes,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                      onPressed: () => _deleteWeightLog(entry),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCareSheetTab(BuildContext context, Pet pet, bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🏥 Veterinarian & Clinic', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  pet.vetInfo.isNotEmpty ? pet.vetInfo : 'No veterinarian info recorded.',
                  style: TextStyle(
                    fontSize: 13,
                    color: pet.vetInfo.isNotEmpty ? null : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('🏷️ Microchip ID', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  pet.microchipId.isNotEmpty ? pet.microchipId : 'No microchip ID recorded.',
                  style: TextStyle(
                    fontSize: 13,
                    color: pet.microchipId.isNotEmpty ? null : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('📝 Special Notes, Diet & Allergies', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  pet.notes.isNotEmpty ? pet.notes : 'No special notes recorded.',
                  style: TextStyle(
                    fontSize: 13,
                    color: pet.notes.isNotEmpty ? null : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('Open Printable Care Sheet'),
            onPressed: () => CareSheetDialog.show(context, pet),
          ),
        ],
      ),
    );
  }
}
