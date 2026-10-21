import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/medication.dart';
import '../../../data/repositories/medication_repository.dart';
import '../../core/constants.dart';

class MedicationFormDialog extends StatefulWidget {
  final int petId;
  final Medication? medication; // If null, adding new.
  final MedicationRepository medicationRepository;
  final VoidCallback onSaved;

  const MedicationFormDialog({
    super.key,
    required this.petId,
    this.medication,
    required this.medicationRepository,
    required this.onSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required int petId,
    Medication? medication,
    required MedicationRepository medicationRepository,
    required VoidCallback onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => MedicationFormDialog(
        petId: petId,
        medication: medication,
        medicationRepository: medicationRepository,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<MedicationFormDialog> createState() => _MedicationFormDialogState();
}

class _MedicationFormDialogState extends State<MedicationFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _dosage;
  late String _frequency;
  late String _timeOfDay;
  late String _startDate;
  late String _endDate;
  late String _prescribingVet;
  late String _instructions;
  late bool _isActive;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    _name = m?.name ?? '';
    _dosage = m?.dosage ?? '';
    _frequency = m?.frequency ?? 'Once daily';
    _timeOfDay = m?.timeOfDay ?? 'Morning';
    _startDate = m?.startDate.isNotEmpty == true
        ? m!.startDate
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
    _endDate = m?.endDate ?? '';
    _prescribingVet = m?.prescribingVet ?? '';
    _instructions = m?.instructions ?? '';
    _isActive = m?.isActive ?? true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final payload = <String, dynamic>{
      'name': _name.trim(),
      'dosage': _dosage.trim(),
      'frequency': _frequency,
      'time_of_day': _timeOfDay,
      'start_date': _startDate,
      'end_date': _endDate,
      'prescribing_vet': _prescribingVet.trim(),
      'instructions': _instructions.trim(),
      'is_active': _isActive,
    };

    try {
      if (widget.medication == null) {
        await widget.medicationRepository.addMedication(widget.petId, payload);
      } else {
        await widget.medicationRepository.updateMedication(widget.medication!.id, payload);
      }
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.medication != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Medication' : 'Add Medication',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 20),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x26EF4444) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextFormField(
                          initialValue: _name,
                          decoration: const InputDecoration(
                            labelText: 'Medication Name *',
                            hintText: 'e.g. Apoquel, Amoxicillin, Felimazole',
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Medication name is required' : null,
                          onSaved: (v) => _name = v ?? '',
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: _dosage,
                                decoration: const InputDecoration(
                                  labelText: 'Dosage *',
                                  hintText: 'e.g. 16 mg, 1 chewable',
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Dosage is required' : null,
                                onSaved: (v) => _dosage = v ?? '',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                initialValue: AppConstants.frequencies.contains(_frequency) ? _frequency : 'Once daily',
                                decoration: const InputDecoration(labelText: 'Frequency *'),
                                items: AppConstants.frequencies.map((f) {
                                  return DropdownMenuItem(value: f, child: Text(f));
                                }).toList(),
                                onChanged: (v) => setState(() => _frequency = v ?? 'Once daily'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: AppConstants.timesOfDay.contains(_timeOfDay) ? _timeOfDay : 'Morning',
                                decoration: const InputDecoration(labelText: 'Time of Day'),
                                items: AppConstants.timesOfDay.map((t) {
                                  return DropdownMenuItem(value: t, child: Text(t));
                                }).toList(),
                                onChanged: (v) => setState(() => _timeOfDay = v ?? 'Morning'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: _startDate,
                                decoration: const InputDecoration(
                                  labelText: 'Start Date',
                                  hintText: 'YYYY-MM-DD',
                                ),
                                onSaved: (v) => _startDate = v?.trim() ?? '',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: _endDate,
                                decoration: const InputDecoration(
                                  labelText: 'End Date (Optional)',
                                  hintText: 'YYYY-MM-DD',
                                ),
                                onSaved: (v) => _endDate = v?.trim() ?? '',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: _prescribingVet,
                                decoration: const InputDecoration(
                                  labelText: 'Prescribing Vet',
                                  hintText: 'e.g. Dr. Adams',
                                ),
                                onSaved: (v) => _prescribingVet = v ?? '',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        TextFormField(
                          initialValue: _instructions,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Instructions & Administration Notes',
                            hintText: 'e.g. Give with peanut butter after breakfast',
                          ),
                          onSaved: (v) => _instructions = v ?? '',
                        ),
                        const SizedBox(height: 12),

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Medication is currently active', style: TextStyle(fontSize: 14)),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEditing ? 'Save Changes' : 'Save Medication'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
