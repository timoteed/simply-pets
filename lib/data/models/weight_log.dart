class WeightLog {
  final int id;
  final int petId;
  final double weight;
  final String weightUnit;
  final String loggedDate;
  final String notes;
  final String createdAt;

  const WeightLog({
    required this.id,
    required this.petId,
    required this.weight,
    required this.weightUnit,
    required this.loggedDate,
    required this.notes,
    required this.createdAt,
  });

  factory WeightLog.fromJson(Map<String, dynamic> json) {
    return WeightLog(
      id: json['id'] as int? ?? 0,
      petId: json['pet_id'] as int? ?? 0,
      weight: (json['weight'] as num?)?.toDouble() ?? 0.0,
      weightUnit: json['weight_unit'] as String? ?? 'lbs',
      loggedDate: json['logged_date'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pet_id': petId,
      'weight': weight,
      'weight_unit': weightUnit,
      'logged_date': loggedDate,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}
