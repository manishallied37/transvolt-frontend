import 'package:jwt_decoder/jwt_decoder.dart';
import 'token_storage.dart';
import 'auth_service.dart';

class AuthState {
  static Future<Map<String, dynamic>?> _getDecodedToken() async {
    String? token = await TokenStorage.getAccessToken();

    if (token == null) return null;

    if (JwtDecoder.isExpired(token)) {
      bool refreshed = await AuthService.refreshAccessToken();

      if (!refreshed) return null;

      token = await TokenStorage.getAccessToken();
    }

    if (token == null) return null;

    return JwtDecoder.decode(token);
  }

  static Future<bool> isLoggedIn() async {
    String? token = await TokenStorage.getAccessToken();

    if (token == null) return false;

    bool isExpired = JwtDecoder.isExpired(token);

    if (!isExpired) return true;

    bool refreshed = await AuthService.refreshAccessToken();

    return refreshed;
  }

  static Future<String?> getUserRole() async {
    var decoded = await _getDecodedToken();
    return decoded?["role"];
  }

  static Future<String?> getUserEmail() async {
    var decoded = await _getDecodedToken();
    return decoded?["email"];
  }

  static Future<String?> getRegion() async {
    var decoded = await _getDecodedToken();
    return decoded?["region"];
  }

  static Future<String?> getDepot() async {
    var decoded = await _getDecodedToken();
    return decoded?["depot"];
  }

  static Future<String?> getUsername() async {
    var decoded = await _getDecodedToken();
    return decoded?["username"];
  }

  static Future<void> logout() async {
    await AuthService.logout();
  }
}
