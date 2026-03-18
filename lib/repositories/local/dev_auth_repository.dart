
import '../auth_repository.dart';
import '../../models/user_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DevAuthRepository implements AuthRepository {
  String? _currentUserId;
  UserRole? _currentUserRole;

  @override
  String? get currentUserId => _currentUserId;

  @override
UserRole? get currentUserRole => _currentUserRole;

final Set<String> _adminUserIds = {
  'admin',
  // add more admin IDs here later
};

@override
Future<void> signIn(String userId) async {
  _currentUserId = userId;

  if (_adminUserIds.contains(userId)) {
    _currentUserRole = UserRole.admin;
    
  } else {
    _currentUserRole = UserRole.user;
  }

  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('currentUserId', userId);
}

@override
bool get isAdmin => _currentUserRole == UserRole.admin;

@override
Future<void> signOut() async {
  _currentUserId = null;
  _currentUserRole = null;

  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('currentUserId');
}

@override
Future<void> restoreSession() async {
  final prefs = await SharedPreferences.getInstance();
  final storedUserId = prefs.getString('currentUserId');

  if (storedUserId == null) return;

  _currentUserId = storedUserId;

  if (_adminUserIds.contains(storedUserId)) {
    _currentUserRole = UserRole.admin;
  } else {
    _currentUserRole = UserRole.user;
  }
}
}