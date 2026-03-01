abstract class AuthRepository {
  String? get currentUserId;

  /// NEW — user role (admin or user)
  String? get currentUserRole;

  Future<void> signIn(String userId);

  Future<void> signOut();
}