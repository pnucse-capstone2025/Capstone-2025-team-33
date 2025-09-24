import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 비밀번호 표시/가리기 상태
  bool _isPasswordVisible = false;

  // 로그인 처리 중 상태
  bool _isLoading = false;

  // ID와 Password 입력값을 관리하기 위한 컨트롤러
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 허용 문자 패턴 (영문 대/소문자, 숫자, _-!@.)
  final RegExp _allowed = RegExp(r'^[a-zA-Z0-9_\-!@.]+$');

  // 토큰 저장용 스토리지
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // 개발용 백엔드 베이스 URL
  //  - iOS 시뮬레이터: http://127.0.0.1:8000
  //  - Android 에뮬레이터: http://10.0.2.2:8000
  static const String _baseUrl = 'http://127.0.0.1:8000';

  @override
  void dispose() {
    // 메모리 누수 방지를 위해 컨트롤러 해제
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 로그인 API 호출 로직 (Django SimpleJWT: /api/auth/login/)
  Future<void> _loginWithApi() async {
    final id = _idController.text.trim();
    final pw = _passwordController.text;

    // 프론트 단 유효성 검사 (ID 형식, PW 길이/문자)
    if (id.isEmpty || !_allowed.hasMatch(id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ID 형식이 올바르지 않습니다.')));
      return;
    }
    if (pw.length < 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('비밀번호는 8자 이상이어야 합니다.')));
      return;
    }
    if (!_allowed.hasMatch(pw)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호에 허용되지 않는 문자가 포함되어 있습니다.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('$_baseUrl/api/auth/login/');
      final resp = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': id, 'password': pw}),
      );

      if (resp.statusCode == 200) {
        final map = jsonDecode(resp.body) as Map<String, dynamic>;
        final access = map['access'] as String?;
        final refresh = map['refresh'] as String?;

        if (access == null) {
          throw Exception('No access token in response');
        }

        // 토큰 안전 저장
        await _storage.write(key: 'access_token', value: access);
        if (refresh != null) {
          await _storage.write(key: 'refresh_token', value: refresh);
        }

        if (!mounted) return;
        // 성공: HOME 화면으로 교체 네비게이션
        Navigator.pushReplacementNamed(context, '/root');
      } else {
        // 서버 인증 실패 (401/400 등)
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인 실패 (${resp.statusCode})')));
      }
    } catch (e) {
      // 네트워크/예외 처리
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 로그인 버튼 핸들러 (API 호출)
  void _onLoginPressed() {
    if (_isLoading) return; // 중복 클릭 방지
    _loginWithApi();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              // 로고 (현재는 텍스트로 대체)
              const Center(
                child: Text(
                  'OutfitterAI',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Login 제목
              const Text(
                'Login',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xffbf634e),
                ),
              ),

              const SizedBox(height: 24),

              // ID 라벨
              const Text('ID', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),

              // ID 입력 필드 (20자 미만, 허용문자만)
              TextField(
                controller: _idController,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(20),
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^[a-zA-Z0-9_\-!@.]*$'),
                  ),
                ],
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                  hintText: 'Enter your ID',
                ),
              ),

              const SizedBox(height: 20),

              // PASSWORD 라벨
              const Text('PASSWORD', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 8),

              // 비밀번호 입력 필드 (8~19자, 허용문자만, 👁️ 토글)
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(20),
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^[a-zA-Z0-9_\-!@.]*$'),
                  ),
                ],
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  hintText: 'Enter your password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Login 버튼
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffbfb69b),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _onLoginPressed,
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // // or 텍스트
              // const Center(child: Text('or', style: TextStyle(fontSize: 18))),

              // const SizedBox(height: 20),

              // Google 로그인 버튼
              // SizedBox(
              //   width: double.infinity,
              //   height: 50,
              //   child: OutlinedButton.icon(
              //     onPressed: () {
              //       // TODO: 구글 로그인 연동 예정
              //     },
              //     icon: const Icon(Icons.g_mobiledata),
              //     label: const Text(
              //       'Sign in with Google',
              //       style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              //     ),
              //     style: OutlinedButton.styleFrom(
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(40),
              //       ),
              //       side: const BorderSide(color: Color(0xff8e908e)),
              //     ),
              //   ),
              // ),
              const SizedBox(height: 30),

              // 회원가입 유도 텍스트
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("don’t have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xffbfb69b),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
