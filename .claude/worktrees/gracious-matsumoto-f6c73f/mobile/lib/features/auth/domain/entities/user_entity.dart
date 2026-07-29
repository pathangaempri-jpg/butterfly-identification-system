import 'package:equatable/equatable.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// USER ENTITY (domain layer — no JSON, no serialization)
/// ─────────────────────────────────────────────────────────────────────────────

class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    this.bio,
    this.profileImageUrl,
    this.role = UserRole.user,
    this.observationCount = 0,
    this.speciesCount = 0,
    this.isVerified = false,
    this.createdAt,
  });

  final String id;
  final String username;
  final String email;
  final String fullName;
  final String? bio;
  final String? profileImageUrl;
  final UserRole role;
  final int observationCount;
  final int speciesCount;
  final bool isVerified;
  final DateTime? createdAt;

  bool get isAdmin => role == UserRole.admin || role == UserRole.superAdmin;
  bool get isModerator => role == UserRole.moderator || isAdmin;

  String get initials => fullName
      .split(' ')
      .take(2)
      .map((n) => n.isNotEmpty ? n[0].toUpperCase() : '')
      .join();

  UserEntity copyWith({
    String? fullName,
    String? bio,
    String? profileImageUrl,
    int? observationCount,
    int? speciesCount,
  }) =>
      UserEntity(
        id: id,
        username: username,
        email: email,
        fullName: fullName ?? this.fullName,
        bio: bio ?? this.bio,
        profileImageUrl: profileImageUrl ?? this.profileImageUrl,
        role: role,
        observationCount: observationCount ?? this.observationCount,
        speciesCount: speciesCount ?? this.speciesCount,
        isVerified: isVerified,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id,
        username,
        email,
        fullName,
        bio,
        profileImageUrl,
        role,
        observationCount,
        speciesCount,
        isVerified,
      ];
}

enum UserRole {
  user,
  moderator,
  admin,
  superAdmin;

  static UserRole fromString(String s) => UserRole.values.firstWhere(
        (r) => r.name == s,
        orElse: () => UserRole.user,
      );
}
