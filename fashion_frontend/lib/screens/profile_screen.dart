// profile_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ★ 토큰 저장소
  final storage = const FlutterSecureStorage();

  // ★ 상태
  Map<String, dynamic>? _user;
  String? _selectedGender;
  bool _loadingUser = true;
  bool _loadingCount = true;
  int _clothesCount = 0;

  // ★ 베이스 URL (iOS: 127.0.0.1 / Android 에뮬레이터: 10.0.2.2)
  static const String _base = 'http://127.0.0.1:8000';

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  // ---------------- API: 사용자 정보 ----------------
  Future<void> _fetchUser() async {
    try {
      final token = await storage.read(key: "access_token");
      if (token == null) {
        setState(() => _loadingUser = false);
        return;
      }

      final res = await http.get(
        Uri.parse("$_base/api/auth/me/"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _user = data;
          _selectedGender = data['gender'] as String?;
          _loadingUser = false;
        });
        // 사용자 로드 후 옷 수 로드
        _fetchClothesCount();
      } else {
        setState(() => _loadingUser = false);
      }
    } catch (_) {
      setState(() => _loadingUser = false);
    }
  }

  // ---------------- API: 옷 개수 ----------------
  Future<void> _fetchClothesCount() async {
    setState(() => _loadingCount = true);
    try {
      final token = await storage.read(key: "access_token");
      if (token == null) {
        setState(() {
          _clothesCount = 0;
          _loadingCount = false;
        });
        return;
      }

      final res = await http.get(
        Uri.parse("$_base/api/clothes/"),
        headers: {"Authorization": "Bearer $token"},
      );

      debugPrint("[clothes] status=${res.statusCode}");
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        debugPrint("[clothes] length=${list.length}");
        setState(() {
          _clothesCount = list.length; // ← 로그인 사용자의 아이템 수
          _loadingCount = false;
        });
      } else {
        setState(() => _loadingCount = false);
      }
    } catch (e) {
      debugPrint("[clothes] error=$e");
      setState(() => _loadingCount = false);
    }
  }

  // ---------------- API: 성별 변경 ----------------
  Future<void> _updateGender(String newGender) async {
    final token = await storage.read(key: "access_token");
    if (token == null) return;

    final res = await http.patch(
      Uri.parse("$_base/api/auth/me/"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"gender": newGender}),
    );

    if (res.statusCode == 200) {
      setState(() {
        _selectedGender = newGender;
        if (_user != null) _user!['gender'] = newGender;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update gender (${res.statusCode})")),
      );
    }
  }

  // ---------------- 로그아웃 ----------------
  Future<void> _logout() async {
    await storage.delete(key: "access_token");
    await storage.delete(key: "refresh_token");
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffbfbfb),
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: const Color(0xFFBFB69B),
        actions: [
          // ★ 수동 새로고침
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchUser();
              _fetchClothesCount();
            },
          ),
        ],
      ),
      body: _loadingUser
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ---------- 프로필 카드 ----------
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 아이디(유저명)
                          Text(
                            "ID : ${_user?['username'] ?? '-'}",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xff333333),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 성별 드롭다운
                          Row(
                            children: [
                              const Text(
                                "Gender:",
                                style: TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 12),
                              DropdownButton<String>(
                                value: _selectedGender,
                                items: const [
                                  DropdownMenuItem(
                                    value: "Men",
                                    child: Text("Men"),
                                  ),
                                  DropdownMenuItem(
                                    value: "Women",
                                    child: Text("Women"),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v != null) _updateGender(v);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // 옷 개수 + 아이콘
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.checkroom,
                                color: Color(0xFFBF634E),
                              ),
                              const SizedBox(width: 8),
                              _loadingCount
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      "You have $_clothesCount items in your closet.",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xff555555),
                                      ),
                                    ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ---------- 로그아웃 버튼 ----------
                  SizedBox(
                    width: 140,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBF634E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
