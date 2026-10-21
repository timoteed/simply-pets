import '../models/medication.dart';
import '../services/api_service.dart';

class MedicationRepository {
  final ApiService apiService;

  MedicationRepository({required this.apiService});

  Future<Medication> addMedication(int petId, Map<String, dynamic> data) async {
    final res = await apiService.post('/api/pets/$petId/medications', data);
    return Medication.fromJson(res as Map<String, dynamic>);
  }

  Future<Medication> updateMedication(int medId, Map<String, dynamic> data) async {
    final res = await apiService.put('/api/medications/$medId', data);
    return Medication.fromJson(res as Map<String, dynamic>);
  }

  Future<bool> deleteMedication(int medId) async {
    await apiService.delete('/api/medications/$medId');
    return true;
  }

  Future<Map<String, dynamic>> logDose(int medId, {String notes = ''}) async {
    final res = await apiService.post('/api/medications/$medId/dose', {
      'notes': notes,
    });
    return res as Map<String, dynamic>;
  }

  Future<List<Medication>> getTodayMedications() async {
    final res = await apiService.get('/api/medications/today');
    if (res is List) {
      return res.map((item) => Medication.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
