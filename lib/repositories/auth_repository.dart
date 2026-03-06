import '../models/user_role.dart';

abstract class AuthRepository {
  String? get currentUserId;

  /// NEW — user role (admin or user)
  UserRole? get currentUserRole;

  Future<void> signIn(String userId);

  Future<void> signOut();
}