class User {
  final int id;
  final String username;
  final String displayName;
  final String createdAt;

  const User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      displayName: (json['display_name'] as String?)?.isNotEmpty == true
          ? json['display_name'] as String
          : (json['username'] as String? ?? ''),
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'created_at': createdAt,
    };
  }
}

class AuthResponse {
  final User user;
  final String token;

  const AuthResponse({
    required this.user,
    required this.token,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: User.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      token: json['token'] as String? ?? '',
    );
  }
}
