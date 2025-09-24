// bottom_nav.dart
// ★ 주석은 한국어로 작성했습니다.
import 'package:flutter/material.dart';
import 'package:fashion_frontend/screens/profile_screen.dart'; // ★ 追加

/// ----------------------------------------------
/// ★ 색상 상수 정의
/// ----------------------------------------------
const Color primary = Color(0xFFBFB69B); // 배경색
const Color textSecondary = Color(0xFFE3E3E3); // 기본 글자/아이콘 색
const Color secondary = Color(0xFFBF634E); // 선택된 상태 색

/// ----------------------------------------------
/// ★ 외부에서 탭을 제어하기 위한 공개 컨트롤러
/// ----------------------------------------------
abstract class BottomNavController {
  /// ★ 외부에서 탭 전환을 요청
  void switchTab(int index);
}

/// ----------------------------------------------
/// ★ Bottom Navigation 루트
/// ----------------------------------------------
class BottomNavRoot extends StatefulWidget {
  final int initialIndex;
  final Widget? home;
  final Widget? calendar;
  final Widget? wardrobe;
  final Widget? profile;

  const BottomNavRoot({
    super.key,
    this.initialIndex = 0,
    this.home,
    this.calendar,
    this.wardrobe,
    this.profile,
  });

  /// ★ 어디서든 상위 트리에서 BottomNav 컨트롤러를 가져오기
  static BottomNavController? maybeOf(BuildContext context) {
    // 내부 State 를 컨트롤러 인터페이스로 노출
    return context.findAncestorStateOfType<_BottomNavRootState>();
  }

  @override
  State<BottomNavRoot> createState() => _BottomNavRootState();
}

class _BottomNavRootState extends State<BottomNavRoot>
    implements BottomNavController {
  late int _currentIndex;
  final _homeKey = GlobalKey<NavigatorState>();
  final _calendarKey = GlobalKey<NavigatorState>();
  final _wardrobeKey = GlobalKey<NavigatorState>();
  final _profileKey = GlobalKey<NavigatorState>();

  late final List<GlobalKey<NavigatorState>> _navKeys;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 3);
    _navKeys = [_homeKey, _calendarKey, _wardrobeKey, _profileKey];
  }

  NavigatorState? get _currentNavigator => _navKeys[_currentIndex].currentState;

  Future<bool> _onWillPop() async {
    if (_currentNavigator?.canPop() == true) {
      _currentNavigator!.pop();
      return false;
    }
    return true;
  }

  // ★ BottomNavigationBar 탭 탭 처리
  void _onTap(int newIndex) {
    if (newIndex == _currentIndex) {
      final nav = _navKeys[newIndex].currentState;
      if (nav != null && nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
    } else {
      setState(() => _currentIndex = newIndex);
    }
  }

  // ★ 외부에서 호출 가능한 탭 전환 (BottomNavController)
  @override
  void switchTab(int index) {
    if (index == _currentIndex) {
      final nav = _navKeys[index].currentState;
      if (nav != null && nav.canPop()) {
        nav.popUntil((r) => r.isFirst);
      }
      return;
    }
    setState(() => _currentIndex = index);
  }

  Widget _buildHome() => widget.home ?? const _HomePage();
  Widget _buildCalendar() => widget.calendar ?? const _CalendarPage();
  Widget _buildWardrobe() => widget.wardrobe ?? const _WardrobePage();
  Widget _buildProfile() => widget.profile ?? const ProfileScreen();

  List<Widget> get _tabNavigators => [
    _TabNavigator(navigatorKey: _homeKey, child: _buildHome()),
    _TabNavigator(navigatorKey: _calendarKey, child: _buildCalendar()),
    _TabNavigator(navigatorKey: _wardrobeKey, child: _buildWardrobe()),
    _TabNavigator(navigatorKey: _profileKey, child: _buildProfile()),
  ];

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Stack(
          children: List.generate(_tabNavigators.length, (index) {
            return Offstage(
              offstage: _currentIndex != index,
              child: _tabNavigators[index],
            );
          }),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          onTap: _onTap,
          backgroundColor: primary,
          selectedItemColor: secondary,
          unselectedItemColor: textSecondary,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.checkroom_outlined),
              activeIcon: Icon(Icons.checkroom),
              label: 'Wardrobe',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const _TabNavigator({required this.navigatorKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: (_) => child, settings: settings);
      },
    );
  }
}

// 이하 데모용 페이지(생략 가능)
class _HomePage extends StatelessWidget {
  const _HomePage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const Center(child: Text('Home')),
    );
  }
}

class _CalendarPage extends StatelessWidget {
  const _CalendarPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: const Center(child: Text('Calendar')),
    );
  }
}

class _WardrobePage extends StatelessWidget {
  const _WardrobePage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wardrobe')),
      body: const Center(child: Text('Wardrobe')),
    );
  }
}

class _ProfilePage extends StatelessWidget {
  const _ProfilePage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('Profile')),
    );
  }
}
