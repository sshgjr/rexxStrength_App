import 'package:flutter/material.dart';

class MemberPage extends StatelessWidget {
  final String username;
  final String email;
  final String token;

  const MemberPage({
    super.key,
    required this.username,
    required this.email,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("회원 페이지")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("닉네임: $username"),
            const SizedBox(height: 10),
            Text("이메일: $email"),
            const SizedBox(height: 10),
            Text("token: $token"),
          ],
        ),
      ),
    );
  }
}
