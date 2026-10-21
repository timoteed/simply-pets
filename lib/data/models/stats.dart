class Stats {
  final int totalPets;
  final int activeMedications;
  final int medsTakenToday;

  const Stats({
    this.totalPets = 0,
    this.activeMedications = 0,
    this.medsTakenToday = 0,
  });

  factory Stats.fromJson(Map<String, dynamic> json) {
    return Stats(
      totalPets: (json['total_pets'] as num?)?.toInt() ?? 0,
      activeMedications: (json['active_medications'] as num?)?.toInt() ?? 0,
      medsTakenToday: (json['meds_taken_today'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_pets': totalPets,
      'active_medications': activeMedications,
      'meds_taken_today': medsTakenToday,
    };
  }
}
