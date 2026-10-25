class User {
  String? userId;
  String? email;
  String? firstName;
  String? lastName;
  String? username;
  String? role; // 'user' | 'admin'
  String? status; // 'online' | 'offline'
  bool? archived;
  DateTime? createdAt;
  String? token;
  String? refreshToken;
  int? xp;

  User({
    required this.userId,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.role,
    required this.status,
    required this.archived,
    required this.createdAt,
    required this.token,
    this.refreshToken,
    this.xp = 0
  });

  // Getter pembantu untuk mengambil nama tampilan pengguna secara konsisten
  String get fullName {
    final first = firstName ?? '';
    final last = lastName ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;
    if (username != null && username!.isNotEmpty) return username!;
    return 'Pengguna';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'] ?? '',
    email: json['email'] ?? '',
    firstName: json['firstName'] ?? json['first_name'] ?? '',
    lastName: json['lastName'] ?? json['last_name'] ?? '',
    username: json['username'] ?? '',
    role: json['role'] ?? '',
    status: json['status'] ?? '',
    archived: json['archived'] ?? false,
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    token: json['token'] ?? '',
    refreshToken: json['refreshToken'] ?? json['refresh_token'] ?? '',
    xp: (json['xp'] as num?)?.toInt() ?? 0
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'role': role,
      'status': status,
      'archived': archived,
      'createdAt': createdAt?.toIso8601String(),
      'token': token,
      'refreshToken': refreshToken,
      'xp' : xp
    };
  }
}