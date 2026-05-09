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
        throw Exception(_extractErrorDetail(response.body, '로그인 실패'));
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
        throw Exception(_extractErrorDetail(response.body, '회원가입 실패'));
      }
    } on SocketException catch (e) {
      debugPrint('[AuthService] 네트워크 연결 오류: $e');
      throw Exception("서버에 연결할 수 없습니다. 네트워크를 확인해주세요.");
    } catch (e) {
      debugPrint('[AuthService] 회원가입 오류: $e');
      rethrow;
    }
  }

  /// 온보딩 필요 여부 조회.
  Future<bool> getOnboardingStatus(String token) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/me/onboarding-status"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body["needs_onboarding"] == true;
      }
      // 실패 시 조용히 false (다음 부팅에 재시도)
      return false;
    } catch (e) {
      debugPrint('[AuthService] onboarding-status 조회 실패: $e');
      return false;
    }
  }

  /// 온보딩 데이터 제출 + 자동 등급 산정 결과 반환.
  Future<Map<String, dynamic>> submitOnboarding({
    required String token,
    String? sex,
    int? birthYear,
    String? trainingExperience,
    double? squat1rm,
    double? bench1rm,
    double? deadlift1rm,
  }) async {
    final body = <String, dynamic>{};
    if (sex != null) body["sex"] = sex;
    if (birthYear != null) body["birth_year"] = birthYear;
    if (trainingExperience != null) body["training_experience"] = trainingExperience;
    if (squat1rm != null) body["squat_1rm"] = squat1rm;
    if (bench1rm != null) body["bench_1rm"] = bench1rm;
    if (deadlift1rm != null) body["deadlift_1rm"] = deadlift1rm;

    try {
      final response = await http.post(
        Uri.parse("${ApiConfig.baseUrl}/me/onboarding"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(_extractErrorDetail(response.body, '온보딩 저장 실패'));
    } on SocketException {
      throw Exception("서버에 연결할 수 없습니다. 네트워크를 확인해주세요.");
    }
  }

  /// 내 정보 조회 (level, level_source 포함).
  Future<Map<String, dynamic>> getMe(String token) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/me"),
        headers: {"Authorization": "Bearer $token"},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(_extractErrorDetail(response.body, '내 정보 조회 실패'));
    } on SocketException {
      throw Exception("서버에 연결할 수 없습니다.");
    }
  }

  /// 등급 수동 변경.
  Future<Map<String, dynamic>> updateLevel({
    required String token,
    required String level,
  }) async {
    try {
      final response = await http.put(
        Uri.parse("${ApiConfig.baseUrl}/me/level"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"level": level}),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception(_extractErrorDetail(response.body, '등급 변경 실패'));
    } on SocketException {
      throw Exception("서버에 연결할 수 없습니다.");
    }
  }

  /// non-200 응답에서 오류 메시지 안전하게 추출.
  /// JSON이 아닌 HTML/plain text 응답(예: 500 Internal Server Error)도 처리.
  String _extractErrorDetail(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {
      // JSON 아님 → 서버 내부 오류 가능성
      if (body.trim().toLowerCase().contains('internal server error')) {
        return '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      }
    }
    return fallback;
  }
}
