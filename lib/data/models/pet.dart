import 'medication.dart';
import 'weight_log.dart';

class Pet {
  final int id;
  final int? userId;
  final String name;
  final String species;
  final String breed;
  final String birthdate;
  final String gender;
  final double weight;
  final String weightUnit;
  final String avatar;
  final String photoUrl;
  final String microchipId;
  final String vetInfo;
  final String notes;
  final int activeMedCount;
  final int totalMedCount;
  final List<Medication> medications;
  final List<WeightLog> weightHistory;
  final String createdAt;
  final String updatedAt;

  const Pet({
    required this.id,
    this.userId,
    required this.name,
    required this.species,
    required this.breed,
    required this.birthdate,
    required this.gender,
    required this.weight,
    required this.weightUnit,
    required this.avatar,
    this.photoUrl = '',
    required this.microchipId,
    required this.vetInfo,
    required this.notes,
    this.activeMedCount = 0,
    this.totalMedCount = 0,
    this.medications = const [],
    this.weightHistory = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    final medsRaw = json['medications'] as List<dynamic>? ?? [];
    final weightsRaw = json['weight_history'] as List<dynamic>? ?? [];

    return Pet(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int?,
      name: json['name'] as String? ?? '',
      species: json['species'] as String? ?? 'Dog',
      breed: json['breed'] as String? ?? '',
      birthdate: json['birthdate'] as String? ?? '',
      gender: json['gender'] as String? ?? 'Unknown',
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      weightUnit: json['weight_unit'] as String? ?? 'lbs',
      avatar: json['avatar'] as String? ?? 'dog',
      photoUrl: json['photo_url'] as String? ?? '',
      microchipId: json['microchip_id'] as String? ?? '',
      vetInfo: json['vet_info'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      activeMedCount: (json['active_med_count'] as num?)?.toInt() ?? 0,
      totalMedCount: (json['total_med_count'] as num?)?.toInt() ?? 0,
      medications: medsRaw
          .map((m) => Medication.fromJson(m as Map<String, dynamic>))
          .toList(),
      weightHistory: weightsRaw
          .map((w) => WeightLog.fromJson(w as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson({bool includeId = false}) {
    final map = <String, dynamic>{
      'name': name,
      'species': species,
      'breed': breed,
      'birthdate': birthdate,
      'gender': gender,
      'weight': weight,
      'weight_unit': weightUnit,
      'avatar': avatar,
      'photo_url': photoUrl,
      'microchip_id': microchipId,
      'vet_info': vetInfo,
      'notes': notes,
    };
    if (includeId) {
      map['id'] = id;
    }
    return map;
  }

  Pet copyWith({
    int? id,
    int? userId,
    String? name,
    String? species,
    String? breed,
    String? birthdate,
    String? gender,
    double? weight,
    String? weightUnit,
    String? avatar,
    String? photoUrl,
    String? microchipId,
    String? vetInfo,
    String? notes,
    int? activeMedCount,
    int? totalMedCount,
    List<Medication>? medications,
    List<WeightLog>? weightHistory,
    String? createdAt,
    String? updatedAt,
  }) {
    return Pet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      birthdate: birthdate ?? this.birthdate,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      avatar: avatar ?? this.avatar,
      photoUrl: photoUrl ?? this.photoUrl,
      microchipId: microchipId ?? this.microchipId,
      vetInfo: vetInfo ?? this.vetInfo,
      notes: notes ?? this.notes,
      activeMedCount: activeMedCount ?? this.activeMedCount,
      totalMedCount: totalMedCount ?? this.totalMedCount,
      medications: medications ?? this.medications,
      weightHistory: weightHistory ?? this.weightHistory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
