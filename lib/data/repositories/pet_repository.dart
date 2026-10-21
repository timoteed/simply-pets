import '../models/pet.dart';
import '../models/stats.dart';
import '../services/api_service.dart';

class PetRepository {
  final ApiService apiService;

  PetRepository({required this.apiService});

  Future<List<Pet>> getAllPets() async {
    final res = await apiService.get('/api/pets');
    if (res is List) {
      return res.map((item) => Pet.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<Pet> getPetById(int id) async {
    final res = await apiService.get('/api/pets/$id');
    return Pet.fromJson(res as Map<String, dynamic>);
  }

  Future<Pet> createPet(Map<String, dynamic> petData) async {
    final res = await apiService.post('/api/pets', petData);
    return Pet.fromJson(res as Map<String, dynamic>);
  }

  Future<Pet> updatePet(int id, Map<String, dynamic> petData) async {
    final res = await apiService.put('/api/pets/$id', petData);
    return Pet.fromJson(res as Map<String, dynamic>);
  }

  Future<bool> deletePet(int id) async {
    await apiService.delete('/api/pets/$id');
    return true;
  }

  Future<String> uploadImage(List<int> bytes, String filename) async {
    final res = await apiService.postMultipart(
      '/api/upload',
      bytes: bytes,
      filename: filename,
    );
    if (res is Map && res['photo_url'] != null) {
      return res['photo_url'].toString();
    }
    throw ApiException('Failed to upload image: invalid response');
  }

  Future<Pet> uploadPetPhoto(int petId, List<int> bytes, String filename) async {
    final res = await apiService.postMultipart(
      '/api/pets/$petId/photo',
      bytes: bytes,
      filename: filename,
    );
    if (res is Map && res['pet'] != null) {
      return Pet.fromJson(res['pet'] as Map<String, dynamic>);
    }
    return getPetById(petId);
  }

  Future<Pet> deletePetPhoto(int petId) async {
    final res = await apiService.delete('/api/pets/$petId/photo');
    if (res is Map && res['pet'] != null) {
      return Pet.fromJson(res['pet'] as Map<String, dynamic>);
    }
    return getPetById(petId);
  }

  Future<Stats> getStats() async {
    final res = await apiService.get('/api/stats');
    return Stats.fromJson(res as Map<String, dynamic>);
  }

  Future<List<Pet>> loadDemoData() async {
    final res = await apiService.post('/api/demo');
    if (res is Map && res['pets'] is List) {
      return (res['pets'] as List)
          .map((item) => Pet.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return getAllPets();
  }

  Future<void> resetAllData() async {
    await apiService.post('/api/reset');
  }

  Future<Map<String, dynamic>> exportData() async {
    final res = await apiService.get('/api/export');
    return res as Map<String, dynamic>;
  }

  Future<int> importData(Map<String, dynamic> backup) async {
    final res = await apiService.post('/api/import', backup);
    if (res is Map && res['message'] != null) {
      return 1;
    }
    return 0;
  }
}
