import '../../config/app_config.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    required this.createdAt,
    this.isAdmin = false,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime createdAt;
  final bool isAdmin;

  static AppUser admin() => AppUser(
        id: AppConfig.adminUserId,
        name: 'Administrator',
        email: AppConfig.adminId,
        createdAt: DateTime(2024, 1, 1),
        isAdmin: true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as String,
        name: map['name'] as String,
        email: map['email'] as String,
        phone: map['phone'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}
