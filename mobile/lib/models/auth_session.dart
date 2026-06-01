class AuthSession {
  const AuthSession({
    required this.userId,
    required this.name,
    required this.phone,
    required this.publicKey,
    required this.token,
  });

  final String userId;
  final String name;
  final String phone;
  final String publicKey;
  final String token;

  factory AuthSession.fromApiMap(Map<String, dynamic> map) {
    final user = (map['user'] as Map<String, dynamic>? ?? const {});
    return AuthSession(
      userId: (user['id'] ?? '').toString(),
      name: (user['name'] ?? '').toString(),
      phone: (user['phone'] ?? user['email'] ?? '').toString(),
      publicKey: (user['publicKey'] ?? '').toString(),
      token: (map['token'] ?? '').toString(),
    );
  }

  factory AuthSession.fromDbMap(Map<String, Object?> map) {
    return AuthSession(
      userId: map['user_id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      publicKey: map['public_key'] as String,
      token: map['token'] as String,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': 1,
      'user_id': userId,
      'name': name,
      'phone': phone,
      'public_key': publicKey,
      'token': token,
    };
  }
}
