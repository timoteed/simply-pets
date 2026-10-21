import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../../data/models/pet.dart';
import '../../core/care_sheet_pdf.dart';
import 'avatar_badge.dart';

typedef PrintDocumentFn = Future<void> Function({
  required String name,
  required Future<Uint8List> Function(PdfPageFormat format) onLayout,
});

Future<void> _defaultPrintDocument({
  required String name,
  required Future<Uint8List> Function(PdfPageFormat format) onLayout,
}) {
  return Printing.layoutPdf(onLayout: onLayout, name: name);
}

class CareSheetDialog extends StatelessWidget {
  final Pet pet;
  final PrintDocumentFn printDocument;

  const CareSheetDialog({
    super.key,
    required this.pet,
    this.printDocument = _defaultPrintDocument,
  });

  static void show(BuildContext context, Pet pet) {
    showDialog(
      context: context,
      builder: (ctx) => CareSheetDialog(pet: pet),
    );
  }

  String _generateCareSheetText() {
    final buffer = StringBuffer();
    buffer.writeln('🐾 SIMPLYPETS CARE SHEET: ${pet.name.toUpperCase()}');
    buffer.writeln('==============================================');
    buffer.writeln('Species: ${pet.species}');
    buffer.writeln('Breed: ${pet.breed.isNotEmpty ? pet.breed : "N/A"}');
    buffer.writeln('Gender: ${pet.gender}');
    buffer.writeln('Weight: ${pet.weight} ${pet.weightUnit}');
    if (pet.birthdate.isNotEmpty) buffer.writeln('Birthdate / Adopted: ${pet.birthdate}');
    if (pet.microchipId.isNotEmpty) buffer.writeln('Microchip ID: ${pet.microchipId}');
    if (pet.vetInfo.isNotEmpty) buffer.writeln('Veterinarian: ${pet.vetInfo}');
    if (pet.notes.isNotEmpty) buffer.writeln('\nSPECIAL NOTES & ALLERGIES:\n${pet.notes}');

    final activeMeds = pet.medications.where((m) => m.isActive).toList();
    buffer.writeln('\nACTIVE MEDICATIONS (${activeMeds.length}):');
    if (activeMeds.isEmpty) {
      buffer.writeln('None');
    } else {
      for (final m in activeMeds) {
        buffer.writeln('- ${m.name} (${m.dosage})');
        buffer.writeln('  Frequency: ${m.frequency} | Timing: ${m.timeOfDay}');
        if (m.prescribingVet.isNotEmpty) buffer.writeln('  Prescribed by: ${m.prescribingVet}');
        if (m.instructions.isNotEmpty) buffer.writeln('  Instructions: ${m.instructions}');
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeMeds = pet.medications.where((m) => m.isActive).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  AvatarBadge(
                    avatar: pet.avatar,
                    photoUrl: pet.photoUrl,
                    size: 48,
                    fontSize: 24,
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
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
                          'Vet & Pet-Sitter Care Sheet',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Overview grid
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Wrap(
                          spacing: 20,
                          runSpacing: 12,
                          children: [
                            _buildInfoItem('Breed', pet.breed.isNotEmpty ? pet.breed : '—'),
                            _buildInfoItem('Gender', pet.gender),
                            _buildInfoItem('Weight', '${pet.weight} ${pet.weightUnit}'),
                            if (pet.birthdate.isNotEmpty)
                              _buildInfoItem('Birthdate / Adopted', pet.birthdate),
                            if (pet.microchipId.isNotEmpty)
                              _buildInfoItem('Microchip ID', pet.microchipId),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Vet Info
                      if (pet.vetInfo.isNotEmpty) ...[
                        _buildSectionHeader('🏥 Veterinarian & Clinic'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            pet.vetInfo,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Special Notes / Allergies
                      if (pet.notes.isNotEmpty) ...[
                        _buildSectionHeader('⚠️ Special Notes & Dietary/Behavioral Info'),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            pet.notes,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Active Medications
                      _buildSectionHeader('💊 Active Medication Schedule (${activeMeds.length})'),
                      if (activeMeds.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'No active medications currently prescribed.',
                            style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        )
                      else
                        ...activeMeds.map((med) => _buildMedCard(context, med, isDark)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Care Sheet'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _generateCareSheetText()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Care sheet copied to clipboard!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Print'),
                    onPressed: () async {
                      try {
                        await printDocument(
                          name: '${pet.name}-care-sheet.pdf',
                          onLayout: (format) => buildCareSheetPdf(pet, format),
                        );
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Printing failed: $e')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildMedCard(BuildContext context, dynamic med, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                med.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  med.dosage,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${med.frequency} • ${med.timeOfDay}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
          ),
          if (med.instructions.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Instructions: ${med.instructions}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
