
import '../auth_repository.dart';

class DevAuthRepository implements AuthRepository {
  String? _currentUserId;
  String? _currentUserRole;

  @override
  String? get currentUserId => _currentUserId;

  @override
  String? get currentUserRole => _currentUserRole;

  @override
  Future<void> signIn(String userId) async {
    _currentUserId = userId;

    // 🔐 Simple DEV role logic
    // You can customize this mapping
    if (userId == 'admin') {
      _currentUserRole = 'admin';
    } else {
      _currentUserRole = 'user';
    }
  }

  @override
  Future<void> signOut() async {
    _currentUserId = null;
    _currentUserRole = null;
  }
}