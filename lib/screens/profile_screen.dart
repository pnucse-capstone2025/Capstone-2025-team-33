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
  final storage = const FlutterSecureStorage();
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _selectedGender;
  int _clothesCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    try {
      final token = await storage.read(key: "access_token");
      if (token == null) {
        setState(() => _loading = false);
        return;
      }

      final url = Uri.parse("http://127.0.0.1:8000/api/auth/me/");
      final response = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _user = data;
          _selectedGender = data['gender'];
          _loading = false;
        });

        // ★ 服の数を取得
        _fetchClothesCount();
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchClothesCount() async {
    final token = await storage.read(key: "access_token");
    if (token == null) return;

    final url = Uri.parse("http://127.0.0.1:8000/api/clothes/");
    final resp = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (resp.statusCode == 200) {
      final List items = jsonDecode(resp.body);
      setState(() {
        _clothesCount = items.length;
      });
    }
  }

  Future<void> _updateGender(String newGender) async {
    final token = await storage.read(key: "access_token");
    if (token == null) return;

    final url = Uri.parse("http://127.0.0.1:8000/api/auth/me/");
    final resp = await http.patch(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
      body: jsonEncode({"gender": newGender}),
    );

    if (resp.statusCode == 200) {
      setState(() {
        _selectedGender = newGender;
        _user!['gender'] = newGender;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update gender (${resp.statusCode})")),
      );
    }
  }

  Future<void> _logout() async {
    await storage.delete(key: "access_token");
    await storage.delete(key: "refresh_token");

    if (!mounted) return;

    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffbfbfb),
      appBar: AppBar(
        title: const Text("Profile"),
        backgroundColor: const Color(0xFFBFB69B),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // ---------- ユーザー情報カード ----------
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ユーザー名
                          Text(
                            "ID (${_user?['username'] ?? '-'})",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff333333),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Gender 選択
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

                          // クローゼット数
                          Row(
                            children: [
                              const Icon(
                                Icons.checkroom,
                                color: Color(0xFFBF634E),
                              ),
                              const SizedBox(width: 8),
                              Text(
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

                  // ---------- ログアウトボタン ----------
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBF634E),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Logout",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
