class Medication {
  final int id;
  final int petId;
  final String name;
  final String dosage;
  final String frequency;
  final String timeOfDay;
  final String startDate;
  final String endDate;
  final String instructions;
  final String prescribingVet;
  final bool isActive;
  final int takenTodayCount;
  final String? lastGivenAt;
  final String? petName;
  final String? petSpecies;
  final String? petAvatar;
  final String? petPhotoUrl;
  final String createdAt;
  final String updatedAt;

  const Medication({
    required this.id,
    required this.petId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.timeOfDay,
    required this.startDate,
    required this.endDate,
    required this.instructions,
    required this.prescribingVet,
    required this.isActive,
    this.takenTodayCount = 0,
    this.lastGivenAt,
    this.petName,
    this.petSpecies,
    this.petAvatar,
    this.petPhotoUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    final activeVal = json['is_active'];
    final bool active = activeVal == 1 || activeVal == true || activeVal == '1' || activeVal == 'true';

    final takenToday = (json['taken_today_count'] ?? json['doses_given_today'] ?? 0) as num;

    return Medication(
      id: json['id'] as int? ?? 0,
      petId: json['pet_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      frequency: json['frequency'] as String? ?? 'Once daily',
      timeOfDay: json['time_of_day'] as String? ?? 'Morning',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      prescribingVet: json['prescribing_vet'] as String? ?? '',
      isActive: active,
      takenTodayCount: takenToday.toInt(),
      lastGivenAt: json['last_given_at'] as String?,
      petName: json['pet_name'] as String?,
      petSpecies: json['pet_species'] as String?,
      petAvatar: json['pet_avatar'] as String?,
      petPhotoUrl: json['pet_photo_url'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pet_id': petId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'time_of_day': timeOfDay,
      'start_date': startDate,
      'end_date': endDate,
      'instructions': instructions,
      'prescribing_vet': prescribingVet,
      'is_active': isActive ? 1 : 0,
    };
  }

  Medication copyWith({
    int? id,
    int? petId,
    String? name,
    String? dosage,
    String? frequency,
    String? timeOfDay,
    String? startDate,
    String? endDate,
    String? instructions,
    String? prescribingVet,
    bool? isActive,
    int? takenTodayCount,
    String? lastGivenAt,
    String? petName,
    String? petSpecies,
    String? petAvatar,
    String? createdAt,
    String? updatedAt,
  }) {
    return Medication(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      instructions: instructions ?? this.instructions,
      prescribingVet: prescribingVet ?? this.prescribingVet,
      isActive: isActive ?? this.isActive,
      takenTodayCount: takenTodayCount ?? this.takenTodayCount,
      lastGivenAt: lastGivenAt ?? this.lastGivenAt,
      petName: petName ?? this.petName,
      petSpecies: petSpecies ?? this.petSpecies,
      petAvatar: petAvatar ?? this.petAvatar,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
