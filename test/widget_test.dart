import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:simply_pets/data/models/medication.dart';
import 'package:simply_pets/data/models/pet.dart';
import 'package:simply_pets/data/models/stats.dart';
import 'package:simply_pets/data/models/user.dart';
import 'package:simply_pets/data/models/weight_log.dart';
import 'package:simply_pets/data/services/storage_service.dart';
import 'package:simply_pets/main.dart';
import 'package:simply_pets/ui/core/constants.dart';
import 'package:simply_pets/ui/core/widgets/avatar_badge.dart';
import 'package:simply_pets/ui/core/widgets/care_sheet_dialog.dart';
import 'package:simply_pets/ui/core/widgets/stat_card.dart';
import 'package:simply_pets/ui/core/widgets/weight_chart.dart';

void main() {
  group('Model Tests', () {
    test('User serialization', () {
      final json = {
        'id': 1,
        'username': 'tim_pets',
        'display_name': 'Tim',
        'created_at': '2026-10-20T12:00:00',
      };
      final user = User.fromJson(json);
      expect(user.id, 1);
      expect(user.username, 'tim_pets');
      expect(user.displayName, 'Tim');
      expect(user.toJson()['username'], 'tim_pets');
    });

    test('Pet serialization with medications and weight history', () {
      final json = {
        'id': 10,
        'user_id': 1,
        'name': 'Luna',
        'species': 'Dog',
        'breed': 'Golden Retriever',
        'birthdate': '2021-04-12',
        'gender': 'Spayed Female',
        'weight': 64.5,
        'weight_unit': 'lbs',
        'avatar': 'dog',
        'microchip_id': '985141002348123',
        'vet_info': 'Dr. Sarah Adams',
        'notes': 'Loves tennis balls',
        'active_med_count': 1,
        'total_med_count': 1,
        'medications': [
          {
            'id': 101,
            'pet_id': 10,
            'name': 'Apoquel',
            'dosage': '16 mg',
            'frequency': 'Once daily',
            'time_of_day': 'Morning',
            'is_active': 1,
            'created_at': '2026-01-01',
            'updated_at': '2026-01-01',
          }
        ],
        'weight_history': [
          {
            'id': 201,
            'pet_id': 10,
            'weight': 64.5,
            'weight_unit': 'lbs',
            'logged_date': '2026-09-10',
            'notes': 'Routine check',
            'created_at': '2026-09-10',
          }
        ],
        'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      };

      final pet = Pet.fromJson(json);
      expect(pet.name, 'Luna');
      expect(pet.species, 'Dog');
      expect(pet.weight, 64.5);
      expect(pet.photoUrl, '');
      expect(pet.activeMedCount, 1);
      expect(pet.medications.length, 1);
      expect(pet.medications.first.name, 'Apoquel');
      expect(pet.medications.first.isActive, true);
      expect(pet.weightHistory.length, 1);
      expect(pet.weightHistory.first.weight, 64.5);

      final outJson = pet.toJson(includeId: true);
      expect(outJson['name'], 'Luna');
      expect(outJson['id'], 10);
      expect(outJson['photo_url'], '');

      final petWithPhoto = pet.copyWith(photoUrl: '/uploads/pet_10_photo.jpg');
      expect(petWithPhoto.photoUrl, '/uploads/pet_10_photo.jpg');
      expect(petWithPhoto.toJson()['photo_url'], '/uploads/pet_10_photo.jpg');
    });

    test('Medication and Dose counting', () {
      final json = {
        'id': 5,
        'pet_id': 1,
        'name': 'Felimazole',
        'dosage': '2.5 mg',
        'frequency': 'Twice daily',
        'time_of_day': 'Morning, Evening',
        'is_active': true,
        'doses_given_today': 2,
        'pet_photo_url': '/uploads/milo.jpg',
        'created_at': '2026-01-01',
        'updated_at': '2026-01-01',
      };
      final med = Medication.fromJson(json);
      expect(med.name, 'Felimazole');
      expect(med.isActive, true);
      expect(med.takenTodayCount, 2);
      expect(med.petPhotoUrl, '/uploads/milo.jpg');
    });

    test('Stats model', () {
      final json = {
        'total_pets': 4,
        'active_medications': 6,
        'meds_taken_today': 3,
      };
      final stats = Stats.fromJson(json);
      expect(stats.totalPets, 4);
      expect(stats.activeMedications, 6);
      expect(stats.medsTakenToday, 3);
    });
  });

  group('UI Core Component Tests', () {
    testWidgets('StatCard displays value and label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StatCard(
              icon: '🐾',
              value: '12',
              label: 'Total Pets Tracked',
              type: StatCardType.primary,
            ),
          ),
        ),
      );

      expect(find.text('12'), findsOneWidget);
      expect(find.text('Total Pets Tracked'), findsOneWidget);
      expect(find.text('🐾'), findsOneWidget);
    });

    testWidgets('AvatarBadge renders emoji correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarBadge(avatar: 'cat'),
          ),
        ),
      );

      expect(find.text('🐱'), findsOneWidget);
    });

    testWidgets('AvatarBadge renders Image when imageBytes provided', (tester) async {
      final fakeBytes = [137, 80, 78, 71, 13, 10, 26, 10]; // PNG header
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvatarBadge(
              avatar: 'dog',
              imageBytes: Uint8List.fromList(fakeBytes),
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('WeightChartWidget renders empty state and points', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WeightChartWidget(logs: [], unit: 'lbs'),
          ),
        ),
      );

      expect(find.text('No weight logs recorded yet'), findsOneWidget);

      final sampleLogs = [
        const WeightLog(
          id: 1,
          petId: 1,
          weight: 60.0,
          weightUnit: 'lbs',
          loggedDate: '2026-01-01',
          notes: '',
          createdAt: '',
        ),
        const WeightLog(
          id: 2,
          petId: 1,
          weight: 64.5,
          weightUnit: 'lbs',
          loggedDate: '2026-06-01',
          notes: '',
          createdAt: '',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WeightChartWidget(logs: sampleLogs, unit: 'lbs'),
          ),
        ),
      );

      expect(find.text('Min: '), findsOneWidget);
      expect(find.text('60.0 lbs'), findsOneWidget);
      expect(find.text('Max: '), findsOneWidget);
      expect(find.text('64.5 lbs'), findsWidgets);
    });

    testWidgets('CareSheetDialog Print generates a printable PDF', (tester) async {
      final pet = Pet.fromJson({'id': 1, 'name': 'Luna'});
      Uint8List? printedBytes;
      String? printedName;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CareSheetDialog(
              pet: pet,
              printDocument: ({required String name, required Future<Uint8List> Function(PdfPageFormat format) onLayout}) async {
                printedName = name;
                printedBytes = await onLayout(PdfPageFormat.a4);
              },
            ),
          ),
        ),
      );

      expect(find.text('Print'), findsOneWidget);

      await tester.tap(find.text('Print'));
      await tester.pumpAndSettle();

      expect(printedName, 'Luna-care-sheet.pdf');
      expect(printedBytes, isNotNull);
      expect(String.fromCharCodes(printedBytes!.take(5)), '%PDF-');
    });

    test('AppConstants mappings', () {
      expect(AppConstants.getAvatarEmoji('dog'), '🐶');
      expect(AppConstants.getAvatarEmoji('cat'), '🐱');
      expect(AppConstants.getAvatarEmoji('rabbit'), '🐰');
      expect(AppConstants.getAvatarEmoji('bird'), '🦜');
      expect(AppConstants.getAvatarEmoji('unknown'), '🐾');
      expect(AppConstants.speciesList.contains('Dog'), true);
      expect(AppConstants.frequencies.contains('Once daily'), true);
    });
  });

  group('Application Integration Smoke Test', () {
    testWidgets('Renders LoginView when not authenticated', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final storage = await StorageService.init();

      await tester.pumpWidget(SimplyPetsApp(storageService: storage));
      await tester.pumpAndSettle();

      expect(find.text('SimplyPets'), findsOneWidget);
      expect(find.text('Log in'), findsWidgets);
      expect(find.text('Create account'), findsOneWidget);
    });
  });
}
