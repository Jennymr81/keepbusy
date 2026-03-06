
import '../auth_repository.dart';
import '../../models/user_role.dart';

class DevAuthRepository implements AuthRepository {
  String? _currentUserId;
  UserRole? _currentUserRole;

  @override
  String? get currentUserId => _currentUserId;

  @override
UserRole? get currentUserRole => _currentUserRole;

  @override
  Future<void> signIn(String userId) async {
    _currentUserId = userId;

   if (userId == 'admin') {
  _currentUserRole = UserRole.admin;
} else {
  _currentUserRole = UserRole.user;
}
  }

  @override
  Future<void> signOut() async {
    _currentUserId = null;
    _currentUserRole = null;
  }
}