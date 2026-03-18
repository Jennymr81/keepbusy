import '../models/user_role.dart';

abstract class AuthRepository {
  String? get currentUserId;

  UserRole? get currentUserRole;

  bool get isAdmin;

  Future<void> signIn(String userId);
  Future<void> signOut();
  Future<void> restoreSession();
}