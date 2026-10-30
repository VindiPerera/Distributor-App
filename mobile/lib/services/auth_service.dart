import 'api_client.dart';

class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _api.post('/login', {
      'email': email,
      'password': password,
    }, withAuth: false);
    await _api.saveToken(data['token']);
    return data['user'];
  }

  Future<void> logout() async {
    try {
      await _api.post('/logout', {});
    } finally {
      await _api.clearToken();
    }
  }

  Future<bool> isLoggedIn() async => (await _api.token) != null;
}
