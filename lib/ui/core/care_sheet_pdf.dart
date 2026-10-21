import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/pet.dart';

/// Builds a printable PDF care sheet for [pet].
Future<Uint8List> buildCareSheetPdf(Pet pet, PdfPageFormat format) async {
  final doc = pw.Document();
  final activeMeds = pet.medications.where((m) => m.isActive).toList();

  pw.Widget sectionTitle(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
        child: pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      );

  pw.Widget infoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.RichText(
          text: pw.TextSpan(
            children: [
              pw.TextSpan(
                text: '$label: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.TextSpan(text: value),
            ],
          ),
        ),
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(36),
      build: (context) => [
        pw.Text(
          'Care Sheet: ${pet.name}',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Vet & Pet-Sitter Record',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 12),
        infoRow('Species', pet.species),
        infoRow('Breed', pet.breed.isNotEmpty ? pet.breed : 'N/A'),
        infoRow('Gender', pet.gender),
        infoRow('Weight', '${pet.weight} ${pet.weightUnit}'),
        if (pet.birthdate.isNotEmpty) infoRow('Birthdate / Adopted', pet.birthdate),
        if (pet.microchipId.isNotEmpty) infoRow('Microchip ID', pet.microchipId),
        if (pet.vetInfo.isNotEmpty) ...[
          sectionTitle('Veterinarian & Clinic'),
          pw.Text(pet.vetInfo),
        ],
        if (pet.notes.isNotEmpty) ...[
          sectionTitle('Special Notes, Diet & Allergies'),
          pw.Text(pet.notes),
        ],
        sectionTitle('Active Medication Schedule (${activeMeds.length})'),
        if (activeMeds.isEmpty)
          pw.Text(
            'No active medications currently prescribed.',
            style: pw.TextStyle(fontStyle: pw.FontStyle.italic),
          )
        else
          ...activeMeds.map(
            (med) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${med.name} (${med.dosage})',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text('${med.frequency} | ${med.timeOfDay}'),
                  if (med.prescribingVet.isNotEmpty)
                    pw.Text('Prescribed by: ${med.prescribingVet}'),
                  if (med.instructions.isNotEmpty)
                    pw.Text('Instructions: ${med.instructions}'),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  return doc.save();
}
