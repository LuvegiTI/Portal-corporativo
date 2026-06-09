import 'package:jwt_decode/jwt_decode.dart';

class JwtHelper {
  static Map<String, dynamic> decode(String token) {
    return Jwt.parseJwt(token);
  }
}