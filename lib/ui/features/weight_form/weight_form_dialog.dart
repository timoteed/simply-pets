import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/repositories/weight_repository.dart';
import '../../core/constants.dart';

class WeightFormDialog extends StatefulWidget {
  final int petId;
  final String defaultUnit;
  final WeightRepository weightRepository;
  final VoidCallback onSaved;

  const WeightFormDialog({
    super.key,
    required this.petId,
    this.defaultUnit = 'lbs',
    required this.weightRepository,
    required this.onSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required int petId,
    String defaultUnit = 'lbs',
    required WeightRepository weightRepository,
    required VoidCallback onSaved,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => WeightFormDialog(
        petId: petId,
        defaultUnit: defaultUnit,
        weightRepository: weightRepository,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<WeightFormDialog> createState() => _WeightFormDialogState();
}

class _WeightFormDialogState extends State<WeightFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  late String _unit;
  late String _date;
  final _notesController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _unit = widget.defaultUnit;
    _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final weightVal = double.tryParse(_weightController.text);
    if (weightVal == null || weightVal < 0) {
      setState(() => _error = 'Please enter a valid weight');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await widget.weightRepository.addWeightLog(
        petId: widget.petId,
        weight: weightVal,
        unit: _unit,
        loggedDate: _date,
        notes: _notesController.text.trim(),
      );
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Record Weight',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Weight *',
                              hintText: 'e.g. 24.5',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          child: DropdownButtonFormField<String>(
                            initialValue: _unit,
                            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                            items: AppConstants.weightUnits.map((u) {
                              return DropdownMenuItem(value: u, child: Text(u));
                            }).toList(),
                            onChanged: (v) => setState(() => _unit = v ?? 'lbs'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      initialValue: _date,
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        hintText: 'YYYY-MM-DD',
                        suffixIcon: Icon(Icons.calendar_today, size: 18),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Date is required' : null,
                      onChanged: (v) => _date = v.trim(),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (Optional)',
                        hintText: 'e.g. Routine checkup, post-diet progress',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
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
                        : const Text('Add Entry'),
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
