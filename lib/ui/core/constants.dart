class AppConstants {
  static const Map<String, String> avatarEmojis = {
    'dog': '🐶',
    'cat': '🐱',
    'rabbit': '🐰',
    'bird': '🦜',
    'hamster': '🐹',
    'paw': '🐾',
    'reptile': '🦎',
    'fish': '🐠',
  };

  static String getAvatarEmoji(String? avatar) {
    if (avatar == null || avatar.isEmpty) return '🐾';
    return avatarEmojis[avatar.toLowerCase()] ?? '🐾';
  }

  static const List<String> speciesList = [
    'Dog',
    'Cat',
    'Rabbit',
    'Bird',
    'Hamster',
    'Reptile',
    'Other',
  ];

  static const List<String> genders = [
    'Unknown',
    'Male',
    'Neutered Male',
    'Female',
    'Spayed Female',
  ];

  static const List<String> frequencies = [
    'Once daily',
    'Twice daily',
    'Every 8 hours',
    'Every other day',
    'Weekly',
    'Monthly',
    'As needed',
    'Custom',
  ];

  static const List<String> timesOfDay = [
    'Morning',
    'Morning, Evening',
    'Noon',
    'Evening',
    'Bedtime',
    'As needed',
  ];

  static const List<String> weightUnits = ['lbs', 'kg'];

  static const Map<String, String> sortLabels = {
    'name_asc': 'Name (A-Z)',
    'name_desc': 'Name (Z-A)',
    'weight_desc': 'Weight (High to Low)',
    'weight_asc': 'Weight (Low to High)',
    'meds_desc': 'Most Medications',
  };
}
