// signup_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'login_screen.dart';

String? _selectedGender; // ★ 성별 선택 저장

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // 입력 컨트롤러
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  // 유효성/상태 플래그
  bool _isIdLenValid = false; // ID 길이 (5~20)
  bool _isIdCharValid = false; // ID 허용문자
  bool _idExists = false; // ID 중복 여부 (서버 확인)
  bool _isCheckingId = false; // ID 중복 확인중 로딩
  bool _isPasswordLenValid = false; // PW 길이 (8~20)
  bool _isPasswordCharValid = false; // PW 허용문자
  bool _obscureText = true; // 비밀번호 가리기

  // 허용 문자 정규식 (영문 대/소문자, 숫자, _-!@.)
  final RegExp _allowed = RegExp(r'^[a-zA-Z0-9_\-!@.]+$');

  // 디바운스 타이머 (ID 중복 체크)
  Timer? _idDebounce;

  // 개발용 백엔드 베이스 URL
  //  - iOS 시뮬레이터: http://127.0.0.1:8000
  //  - Android 에뮬레이터: http://10.0.2.2:8000
  static const String _baseUrl = 'http://127.0.0.1:8000';

  @override
  void initState() {
    super.initState();
    // 초기 상태 계산
    _recomputeIdValidity(_idController.text);
    _recomputePasswordValidity(_passwordController.text);
  }

  @override
  void dispose() {
    _idDebounce?.cancel();
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ID 유효성 재계산 + 디바운스 후 서버 중복 체크
  void _onIdChanged(String value) {
    _recomputeIdValidity(value);

    // 길이/문자 통과한 경우에만 서버 중복 체크 디바운스 실행
    _idDebounce?.cancel();
    if (_isIdLenValid && _isIdCharValid) {
      _idDebounce = Timer(const Duration(milliseconds: 400), () {
        _checkIdExists(value);
      });
    } else {
      setState(() {
        _idExists = false; // 형식 불일치 시 중복 상태는 클리어
      });
    }
  }

  // PW 유효성 재계산
  void _onPasswordChanged(String value) {
    _recomputePasswordValidity(value);
  }

  // ID 길이/문자 유효성만 로컬에서 판단
  void _recomputeIdValidity(String value) {
    setState(() {
      _isIdLenValid = value.length >= 5 && value.length <= 20;
      _isIdCharValid = value.isEmpty ? false : _allowed.hasMatch(value);
    });
  }

  // PW 길이/문자 유효성
  void _recomputePasswordValidity(String value) {
    setState(() {
      _isPasswordLenValid = value.length >= 8 && value.length <= 20;
      _isPasswordCharValid = value.isEmpty ? false : _allowed.hasMatch(value);
    });
  }

  // 서버에 ID 중복 여부 조회: /api/auth/check-id/?username=...
  Future<void> _checkIdExists(String id) async {
    setState(() => _isCheckingId = true);
    try {
      final uri = Uri.parse('$_baseUrl/api/auth/check-id/?username=$id');
      final resp = await http.get(uri);
      if (resp.statusCode == 200) {
        final map = jsonDecode(resp.body) as Map<String, dynamic>;
        final exists = map['exists'] == true;
        setState(() {
          _idExists = exists;
        });
      } else {
        // 서버 오류 시에는 보수적으로 사용 가능으로 간주 (UI 막힘 방지)
        setState(() => _idExists = false);
      }
    } catch (_) {
      // 네트워크 에러 시에도 막지 않음
      setState(() => _idExists = false);
    } finally {
      if (mounted) setState(() => _isCheckingId = false);
    }
  }

  // 회원가입 호출: /api/auth/signup/ (username, password) → 201 기대
  Future<void> _submitSignup() async {
    final id = _idController.text.trim();
    final pw = _passwordController.text;

    // 최종 유효성 (ID는 서버 중복까지 반영)
    final isIdValid = _isIdLenValid && _isIdCharValid && !_idExists;
    final isPwValid = _isPasswordLenValid && _isPasswordCharValid;

    if (!isIdValid || !isPwValid) return;

    try {
      final uri = Uri.parse('$_baseUrl/api/auth/signup/');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': id,
          'password': pw,
          'gender': _selectedGender, // ★ 성별 추가
        }),
      );

      if (resp.statusCode == 201) {
        if (!mounted) return;
        // 성공 시 로그인 화면으로 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else if (resp.statusCode == 409) {
        // 서버가 중복을 409로 응답하는 경우
        setState(() => _idExists = true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign up failed (${resp.statusCode})')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Network error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 버튼 활성 조건
    final isFormValid =
        (_isIdLenValid && _isIdCharValid && !_idExists) &&
        (_isPasswordLenValid && _isPasswordCharValid);

    // ID 입력창의 우측 아이콘 상태 계산
    Widget? _buildIdSuffix() {
      if (_idController.text.isEmpty) return null;
      if (_isCheckingId) {
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
      final showError = !_isIdLenValid || !_isIdCharValid || _idExists;
      return Icon(
        showError ? Icons.error_outline : Icons.check_circle,
        color: showError ? Colors.red : Colors.green,
      );
    }

    // PW 입력창의 우측 아이콘(눈 + 경고)을 Row로 구성
    Widget _buildPasswordSuffix() {
      final showPwLenError =
          !_isPasswordLenValid && _passwordController.text.isNotEmpty;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscureText = !_obscureText),
          ),
          if (showPwLenError)
            const Padding(
              padding: EdgeInsets.only(right: 6.0),
              child: Icon(Icons.error_outline, color: Colors.red),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xfffbfbfb),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35.0),
        child: ListView(
          children: [
            const SizedBox(height: 40),

            // 로고
            const Center(
              child: Text(
                'OutfitterAI',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // 제목
            const Text(
              'SignUp',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xffbf634e),
              ),
            ),

            const SizedBox(height: 30),

            // ID 라벨
            const Text(
              'ID',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),

            // ID 입력창 (5~20자, 허용문자, 중복체크)
            TextField(
              controller: _idController,
              onChanged: _onIdChanged,
              inputFormatters: [
                LengthLimitingTextInputFormatter(20), // 20자 초과 입력 차단
                FilteringTextInputFormatter.allow(
                  RegExp(r'^[a-zA-Z0-9_\-!@.]*$'),
                ),
              ],
              decoration: InputDecoration(
                hintText: 'Enter your ID',
                prefixIcon: const Icon(Icons.person),
                suffixIcon: _buildIdSuffix(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // ID 경고문 (길이/문자)
            if (_idController.text.isNotEmpty &&
                (!_isIdLenValid || !_isIdCharValid))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'ID must be 5 to 20 characters (a-zA-Z0-9 _-!@.)',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            // 중복 경고문
            if (_idController.text.isNotEmpty &&
                _isIdLenValid &&
                _isIdCharValid &&
                _idExists)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'This ID already exists',
                  style: TextStyle(color: Colors.red),
                ),
              ),

            const SizedBox(height: 30),

            // PASSWORD 라벨
            const Text(
              'PASSWORD',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),

            // PASSWORD 입력창 (8~20자, 허용문자, 눈 + 경고아이콘)
            TextField(
              controller: _passwordController,
              onChanged: _onPasswordChanged,
              obscureText: _obscureText,
              inputFormatters: [
                LengthLimitingTextInputFormatter(20), // 20자 초과 입력 차단
                FilteringTextInputFormatter.allow(
                  RegExp(r'^[a-zA-Z0-9_\-!@.]*$'),
                ),
              ],
              decoration: InputDecoration(
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: _buildPasswordSuffix(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            // PASSWORD 경고문 (길이만 명시적으로 요구사항 반영)
            if (_passwordController.text.isNotEmpty && !_isPasswordLenValid)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'password must be 8 to 20 characters',
                  style: TextStyle(color: Colors.red),
                ),
              ),

            const SizedBox(height: 30),

            const SizedBox(height: 30),

            // GENDER 라벨
            const Text(
              'GENDER',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _selectedGender,
              items: const [
                DropdownMenuItem(value: "Men", child: Text("Men")),
                DropdownMenuItem(value: "Women", child: Text("Women")),
              ],
              onChanged: (v) => setState(() => _selectedGender = v),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.person),
              ),
            ),

            // SignUp 버튼 (유효할 때만 활성)
            ElevatedButton(
              onPressed: isFormValid ? _submitSignup : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xffbfb69b),
                padding: const EdgeInsets.symmetric(vertical: 15),
                disabledBackgroundColor: const Color(
                  0xffbfb69b,
                ).withOpacity(0.5),
              ),
              child: const Text(
                'SignUp',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),

            const SizedBox(height: 20),

            // or
            const Center(child: Text('or', style: TextStyle(fontSize: 20))),
            const SizedBox(height: 20),

            // Google 로그인 버튼
            OutlinedButton.icon(
              onPressed: () {
                // 추후 구현 예정
              },
              icon: const Icon(Icons.g_mobiledata, size: 24),
              label: const Text(
                'Sign up with Google',
                style: TextStyle(fontSize: 18),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xff8e908e)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(40),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),

            const SizedBox(height: 30),

            // Already have an account? → Login
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account?'),
                TextButton(
                  onPressed: () {
                    // 로그인 화면으로 이동
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: Color(0xffbfb69b),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
