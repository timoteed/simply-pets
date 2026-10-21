import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/pet.dart';
import '../../../data/repositories/pet_repository.dart';
import '../../core/constants.dart';
import '../../core/widgets/avatar_badge.dart';
import '../../core/widgets/confirm_dialog.dart';

class PetFormDialog extends StatefulWidget {
  final Pet? pet; // If null, creating new pet.
  final PetRepository petRepository;
  final VoidCallback onSaved;
  final VoidCallback? onDeleted;

  const PetFormDialog({
    super.key,
    this.pet,
    required this.petRepository,
    required this.onSaved,
    this.onDeleted,
  });

  static Future<void> show({
    required BuildContext context,
    Pet? pet,
    required PetRepository petRepository,
    required VoidCallback onSaved,
    VoidCallback? onDeleted,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => PetFormDialog(
        pet: pet,
        petRepository: petRepository,
        onSaved: onSaved,
        onDeleted: onDeleted,
      ),
    );
  }

  @override
  State<PetFormDialog> createState() => _PetFormDialogState();
}

class _PetFormDialogState extends State<PetFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _species;
  late String _breed;
  late double _weight;
  late String _weightUnit;
  late String _birthdate;
  late String _gender;
  late String _avatar;
  late String _photoUrl;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _photoRemoved = false;
  late String _microchipId;
  late String _vetInfo;
  late String _notes;

  // Optional initial med fields for new pet
  final _initMedNameController = TextEditingController();
  final _initMedDosageController = TextEditingController();
  String _initMedFreq = 'Once daily';
  final _initMedInstructionsController = TextEditingController();

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.pet;
    _name = p?.name ?? '';
    _species = p?.species ?? 'Dog';
    _breed = p?.breed ?? '';
    _weight = p?.weight ?? 0.0;
    _weightUnit = p?.weightUnit ?? 'lbs';
    _birthdate = p?.birthdate ?? '';
    _gender = p?.gender ?? 'Unknown';
    _avatar = p?.avatar ?? 'dog';
    _photoUrl = p?.photoUrl ?? '';
    _microchipId = p?.microchipId ?? '';
    _vetInfo = p?.vetInfo ?? '';
    _notes = p?.notes ?? '';
  }

  Future<void> _pickPhoto() async {
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
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = picked.name;
          _photoRemoved = false;
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick image: $e');
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
      _photoUrl = '';
      _photoRemoved = true;
    });
  }

  @override
  void dispose() {
    _initMedNameController.dispose();
    _initMedDosageController.dispose();
    _initMedInstructionsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_selectedImageBytes != null) {
        if (widget.pet != null) {
          final updatedPet = await widget.petRepository.uploadPetPhoto(
            widget.pet!.id,
            _selectedImageBytes!,
            _selectedImageName ?? 'photo.jpg',
          );
          _photoUrl = updatedPet.photoUrl;
        } else {
          _photoUrl = await widget.petRepository.uploadImage(
            _selectedImageBytes!,
            _selectedImageName ?? 'photo.jpg',
          );
        }
      } else if (_photoRemoved && widget.pet != null) {
        await widget.petRepository.deletePetPhoto(widget.pet!.id);
        _photoUrl = '';
      }

      final payload = <String, dynamic>{
        'name': _name.trim(),
        'species': _species,
        'breed': _breed.trim(),
        'weight': _weight,
        'weight_unit': _weightUnit,
        'birthdate': _birthdate,
        'gender': _gender,
        'avatar': _avatar,
        'photo_url': _photoUrl,
        'microchip_id': _microchipId.trim(),
        'vet_info': _vetInfo.trim(),
        'notes': _notes.trim(),
        'log_weight_change': true,
      };

      if (widget.pet == null) {
        // New pet: check initial medication
        final mName = _initMedNameController.text.trim();
        if (mName.isNotEmpty) {
          payload['medications'] = [
            {
              'name': mName,
              'dosage': _initMedDosageController.text.trim(),
              'frequency': _initMedFreq,
              'time_of_day': 'Morning',
              'instructions': _initMedInstructionsController.text.trim(),
              'is_active': true,
            }
          ];
        }
      }

      if (widget.pet == null) {
        await widget.petRepository.createPet(payload);
      } else {
        await widget.petRepository.updatePet(widget.pet!.id, payload);
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

  Future<void> _deletePet() async {
    if (widget.pet == null) return;
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete Pet',
      message: 'Are you sure you want to delete ${widget.pet!.name}?',
      warningText: 'This will permanently delete this pet along with all recorded medications, dosing logs, and weight history.',
      confirmLabel: 'Yes, Delete Pet',
      isDestructive: true,
    );

    if (confirmed) {
      try {
        await widget.petRepository.deletePet(widget.pet!.id);
        widget.onDeleted?.call();
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.pet != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Pet Profile' : 'Add New Pet',
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

              // Form content
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name & Species
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: _name,
                                decoration: const InputDecoration(
                                  labelText: 'Pet Name *',
                                  hintText: 'e.g. Bella, Milo',
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Pet name is required' : null,
                                onSaved: (v) => _name = v ?? '',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                initialValue: AppConstants.speciesList.contains(_species) ? _species : 'Other',
                                decoration: const InputDecoration(labelText: 'Species *'),
                                items: AppConstants.speciesList.map((s) {
                                  return DropdownMenuItem(value: s, child: Text(s));
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() {
                                      _species = v;
                                      // Suggest appropriate avatar
                                      if (v == 'Dog') _avatar = 'dog';
                                      if (v == 'Cat') _avatar = 'cat';
                                      if (v == 'Rabbit') _avatar = 'rabbit';
                                      if (v == 'Bird') _avatar = 'bird';
                                      if (v == 'Hamster') _avatar = 'hamster';
                                      if (v == 'Reptile') _avatar = 'reptile';
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Breed & Weight
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                initialValue: _breed,
                                decoration: const InputDecoration(
                                  labelText: 'Breed *',
                                  hintText: 'e.g. Golden Retriever',
                                ),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Breed is required' : null,
                                onSaved: (v) => _breed = v ?? '',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      initialValue: _weight > 0 ? _weight.toString() : '',
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Weight *',
                                        hintText: '24.5',
                                      ),
                                      validator: (v) {
                                        if (v == null || v.trim().isEmpty) return 'Required';
                                        final num = double.tryParse(v);
                                        if (num == null || num < 0) return 'Invalid';
                                        return null;
                                      },
                                      onSaved: (v) => _weight = double.tryParse(v ?? '0') ?? 0.0,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 70,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _weightUnit,
                                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12)),
                                      items: AppConstants.weightUnits.map((u) {
                                        return DropdownMenuItem(value: u, child: Text(u));
                                      }).toList(),
                                      onChanged: (v) => setState(() => _weightUnit = v ?? 'lbs'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Gender & Birthdate
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: AppConstants.genders.contains(_gender) ? _gender : 'Unknown',
                                decoration: const InputDecoration(labelText: 'Gender'),
                                items: AppConstants.genders.map((g) {
                                  return DropdownMenuItem(value: g, child: Text(g));
                                }).toList(),
                                onChanged: (v) => setState(() => _gender = v ?? 'Unknown'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: _birthdate,
                                decoration: const InputDecoration(
                                  labelText: 'Birthdate / Adopted',
                                  hintText: 'YYYY-MM-DD',
                                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                                ),
                                onSaved: (v) => _birthdate = v?.trim() ?? '',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Photo Upload Section
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              AvatarBadge(
                                avatar: _avatar,
                                photoUrl: _photoRemoved ? null : _photoUrl,
                                imageBytes: _selectedImageBytes,
                                baseUrl: widget.petRepository.apiService.baseUrl,
                                size: 64,
                                fontSize: 32,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pet Profile Picture',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Upload a photo or choose an avatar icon below.',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            visualDensity: VisualDensity.compact,
                                          ),
                                          icon: const Icon(Icons.photo_camera, size: 16),
                                          label: Text(
                                            (_selectedImageBytes != null || (!_photoRemoved && _photoUrl.isNotEmpty))
                                                ? 'Change Photo'
                                                : 'Upload Photo',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          onPressed: _isLoading ? null : _pickPhoto,
                                        ),
                                        if (_selectedImageBytes != null || (!_photoRemoved && _photoUrl.isNotEmpty))
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor: const Color(0xFFEF4444),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              visualDensity: VisualDensity.compact,
                                            ),
                                            icon: const Icon(Icons.delete_outline, size: 16),
                                            label: const Text('Remove Photo', style: TextStyle(fontSize: 12)),
                                            onPressed: _isLoading ? null : _removePhoto,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Avatar Picker
                        const Text(
                          'Fallback Avatar Icon',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          children: AppConstants.avatarEmojis.entries.map((entry) {
                            final isSelected = _avatar == entry.key;
                            return GestureDetector(
                              onTap: () => setState(() => _avatar = entry.key),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(entry.value, style: const TextStyle(fontSize: 22)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Microchip ID
                        TextFormField(
                          initialValue: _microchipId,
                          decoration: const InputDecoration(
                            labelText: 'Microchip ID (Optional)',
                            hintText: 'e.g. 985141002348123',
                          ),
                          onSaved: (v) => _microchipId = v ?? '',
                        ),
                        const SizedBox(height: 12),

                        // Veterinarian / Clinic Info
                        TextFormField(
                          initialValue: _vetInfo,
                          decoration: const InputDecoration(
                            labelText: 'Veterinarian / Clinic Info',
                            hintText: 'e.g. Dr. Sarah • Oakwood Vet (555-0192)',
                          ),
                          onSaved: (v) => _vetInfo = v ?? '',
                        ),
                        const SizedBox(height: 12),

                        // Special Notes / Allergies
                        TextFormField(
                          initialValue: _notes,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Special Notes / Allergies',
                            hintText: 'e.g. Allergic to chicken, loves tennis balls',
                          ),
                          onSaved: (v) => _notes = v ?? '',
                        ),

                        // Optional Inline Medication section for new pet
                        if (!isEditing) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '💊 Add Initial Medication (Optional)',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                    ),
                                    Text(
                                      'Can also add later',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _initMedNameController,
                                        decoration: const InputDecoration(
                                          hintText: 'Medication Name (e.g. Apoquel)',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _initMedDosageController,
                                        decoration: const InputDecoration(
                                          hintText: 'Dosage (e.g. 16 mg)',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _initMedFreq,
                                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                                        items: AppConstants.frequencies.map((f) {
                                          return DropdownMenuItem(value: f, child: Text(f));
                                        }).toList(),
                                        onChanged: (v) => setState(() => _initMedFreq = v ?? 'Once daily'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _initMedInstructionsController,
                                        decoration: const InputDecoration(
                                          hintText: 'Instructions (e.g. With food)',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isEditing)
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete Pet'),
                      onPressed: _isLoading ? null : _deletePet,
                    )
                  else
                    const SizedBox.shrink(),
                  Row(
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
                            : Text(isEditing ? 'Save Changes' : 'Save Pet'),
                      ),
                    ],
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
