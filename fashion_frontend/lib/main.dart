// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/wardrobe_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/profile_screen.dart'; // ★ 프로필 화면 임포트
import 'widgets/bottom_nav.dart'; // ★ BottomNavRoot 임포트

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OutfitterAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // ★ 앱 시작 시 스플래시 먼저 실행
      initialRoute: '/',
      navigatorObservers: [routeObserver],

      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/weather': (context) => const WeatherScreen(),

        '/root': (context) => const BottomNavRoot(
          // home: HomeScreen(),
          // calendar: CalendarScreen(),
          // wardrobe: WardrobeScreen(),
          // profile: ProfileScreen(),
        ),
      },
    );
  }
}
