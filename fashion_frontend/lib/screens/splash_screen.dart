import 'package:fashion_frontend/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 2));

    final access = await storage.read(key: "access_token");
    final refresh = await storage.read(key: "refresh_token");

    if (access == null || access.isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final url = Uri.parse("http://127.0.0.1:8000/api/auth/me/");
    final resp = await http.get(
      url,
      headers: {"Authorization": "Bearer $access"},
    );

    if (resp.statusCode == 200) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/root');
    } else if (resp.statusCode == 401 &&
        refresh != null &&
        refresh.isNotEmpty) {
      // --------- リフレッシュ試行 ---------
      final refreshUrl = Uri.parse(
        "http://127.0.0.1:8000/api/auth/token/refresh/",
      );
      final refreshResp = await http.post(
        refreshUrl,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"refresh": refresh}),
      );

      if (refreshResp.statusCode == 200) {
        final data = jsonDecode(refreshResp.body);
        final newAccess = data["access"];
        if (newAccess != null) {
          await storage.write(key: "access_token", value: newAccess);
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/root');
          return;
        }
      }

      // リフレッシュ失敗 → トークン削除 & ログインへ
      await storage.deleteAll();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      // 無効トークン
      await storage.deleteAll();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(
            child: Image.asset(
              'assets/images/splash_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Image.asset('assets/images/outfitter_logo.png'),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: Colors.grey,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.secondary,
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ],
      ),
    );
  }
}
