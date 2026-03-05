import 'package:jwt_decoder/jwt_decoder.dart';
import 'token_storage.dart';

class AuthState {
  static Future<String?> getUserRole() async {
    String? token = await TokenStorage.getAccessToken();

    if (token == null) return null;

    Map<String, dynamic> decoded = JwtDecoder.decode(token);

    return decoded["role"];
  }
}
