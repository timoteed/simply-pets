import '../models/weight_log.dart';
import '../services/api_service.dart';

class WeightRepository {
  final ApiService apiService;

  WeightRepository({required this.apiService});

  Future<WeightLog> addWeightLog({
    required int petId,
    required double weight,
    String unit = 'lbs',
    required String loggedDate,
    String notes = '',
  }) async {
    final res = await apiService.post('/api/pets/$petId/weights', {
      'weight': weight,
      'weight_unit': unit,
      'logged_date': loggedDate,
      'notes': notes,
    });
    return WeightLog.fromJson(res as Map<String, dynamic>);
  }

  Future<bool> deleteWeightLog(int weightId) async {
    await apiService.delete('/api/weights/$weightId');
    return true;
  }
}
