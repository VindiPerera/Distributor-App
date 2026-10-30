import 'package:flutter/foundation.dart';
import '../dev_config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient api = ApiClient();
  late final AuthService authService = AuthService(api);

  bool _isLoggedIn = false;
  Map<String, dynamic>? currentUser;
  bool isLoading = true;

  bool get isLoggedIn => _isLoggedIn;

  AuthProvider() {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    _isLoggedIn = bypassLogin ? false : await authService.isLoggedIn();
    isLoading = false;
    notifyListeners();
  }

  /// DEV ONLY: when true, login skips the API and goes straight to home.
  /// Set to false to restore real authentication.
  static const bool bypassLogin = kDemoMode;

  Future<void> login(String email, String password) async {
    if (bypassLogin) {
      currentUser = {'name': 'Demo User', 'email': email};
      _isLoggedIn = true;
      notifyListeners();
      return;
    }
    currentUser = await authService.login(email, password);
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> logout() async {
    if (!bypassLogin) await authService.logout();
    _isLoggedIn = false;
    currentUser = null;
    notifyListeners();
  }
}
