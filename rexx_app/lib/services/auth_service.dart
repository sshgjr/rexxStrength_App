import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AuthService {
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[AuthService] 로그인 요청: ${ApiConfig.baseUrl}/login');
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[AuthService] 로그인 응답: ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final detail = jsonDecode(response.body)['detail'] ?? '로그인 실패';
        throw Exception(detail);
      }
    } on SocketException catch (e) {
      debugPrint('[AuthService] 네트워크 연결 오류: $e');
      throw Exception("서버에 연결할 수 없습니다. 네트워크를 확인해주세요.");
    } catch (e) {
      debugPrint('[AuthService] 로그인 오류: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    double? height,
    double? weight,
    bool? isBodyPublic,
    List<String>? interests,
  }) async {
    try {
      debugPrint('[AuthService] 회원가입 요청: ${ApiConfig.baseUrl}/register');

      final body = <String, dynamic>{
        "username": username,
        "email": email,
        "password": password,
      };
      if (height != null) body["height"] = height;
      if (weight != null) body["weight"] = weight;
      if (isBodyPublic != null) body["is_body_public"] = isBodyPublic;
      if (interests != null) body["interests"] = interests;

      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      debugPrint('[AuthService] 회원가입 응답: ${response.statusCode}');
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final detail = jsonDecode(response.body)['detail'] ?? '회원가입 실패';
        throw Exception(detail);
      }
    } on SocketException catch (e) {
      debugPrint('[AuthService] 네트워크 연결 오류: $e');
      throw Exception("서버에 연결할 수 없습니다. 네트워크를 확인해주세요.");
    } catch (e) {
      debugPrint('[AuthService] 회원가입 오류: $e');
      rethrow;
    }
  }
}
