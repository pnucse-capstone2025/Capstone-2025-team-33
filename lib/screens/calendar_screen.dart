import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fashion_frontend/screens/add_schedule.dart';
import 'package:fashion_frontend/screens/modify_schedule.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const String _baseUrl = 'http://127.0.0.1:8000';

  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  final Map<int, List<Map<String, dynamic>>> _monthSchedules = {};
  DateTime _today = DateTime.now();
  List<Map<String, dynamic>> _todaySchedules = [];

  bool _isLoadingMonth = false;
  bool _isLoadingToday = false;
  String? _errorMonth;
  String? _errorToday;

  final ScrollController _scrollController = ScrollController();
  static const double _rowHeight = 56.0;

  @override
  void initState() {
    super.initState();
    _fetchToday();
    _fetchMonth();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    const storage = FlutterSecureStorage();
    return await storage.read(key: 'access_token');
  }

  Future<void> _fetchToday() async {
    setState(() {
      _isLoadingToday = true;
      _errorToday = null;
    });
    try {
      final token = await _getToken();
      final todayStr = "${DateTime.now().toIso8601String().split('T').first}";
      final uri = Uri.parse("$_baseUrl/api/events/?date=$todayStr");
      final resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        _todaySchedules = list
            .cast<Map>()
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _today = DateTime.now();
      } else {
        _errorToday = 'Failed to load today (${resp.statusCode})';
      }
    } catch (e) {
      _errorToday = 'Network error: $e';
    } finally {
      if (mounted) setState(() => _isLoadingToday = false);
    }
  }

  Future<void> _fetchMonth() async {
    setState(() {
      _isLoadingMonth = true;
      _errorMonth = null;
      _monthSchedules.clear();
    });
    try {
      final token = await _getToken();
      final y = _currentMonth.year;
      final m = _currentMonth.month;
      final uri = Uri.parse("$_baseUrl/api/events/?year=$y&month=$m");
      final resp = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List;
        for (final e in list) {
          final day = DateTime.parse(e['date']).day;
          _monthSchedules
              .putIfAbsent(day, () => [])
              .add(Map<String, dynamic>.from(e));
        }
      } else {
        _errorMonth = 'Failed to load calendar (${resp.statusCode})';
      }
    } catch (e) {
      _errorMonth = 'Network error: $e';
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingMonth = false);

      if (_currentMonth.year == _today.year &&
          _currentMonth.month == _today.month) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final idx = _today.day - 1;
          final offset = (idx * _rowHeight);
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              offset.clamp(0.0, _scrollController.position.maxScrollExtent),
            );
          }
        });
      } else {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      }
    }
  }

  void _goPrevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _fetchMonth();
  }

  void _goNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _fetchMonth();
  }

  String _weekdayLabel(int y, int m, int d) {
    final wd = DateTime(y, m, d).weekday;
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[wd - 1];
  }

  String _formatTodayHeader(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final wd = _weekdayLabel(dt.year, dt.month, dt.day);
    return '$y/$m/$d ($wd)';
  }

  int _lastDayOfMonth(DateTime month) {
    final firstNext = DateTime(month.year, month.month + 1, 1);
    final last = firstNext.subtract(const Duration(days: 1));
    return last.day;
  }

  @override
  Widget build(BuildContext context) {
    final y = _currentMonth.year;
    final m = _currentMonth.month;
    final lastDay = _lastDayOfMonth(_currentMonth);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.only(
              top: 50,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            color: const Color(0xFFBFB69B),
            child: const Row(
              children: [
                SizedBox(width: 8),
                Text(
                  'Calendar',
                  style: TextStyle(
                    fontFamily: 'Futura',
                    fontSize: 16,
                    color: Color(0xFFF9F2ED),
                  ),
                ),
              ],
            ),
          ),

          // 오늘 일정 + Add Schedule
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _isLoadingToday
                      ? const Text(
                          "Loading today's schedule...",
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        )
                      : (_errorToday != null
                            ? Text(
                                _errorToday!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.red,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatTodayHeader(_today),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _todaySchedules.isEmpty
                                        ? "Today's plan : (No schedule)"
                                        : "Today's plan : ${_todaySchedules.map((e) => e['title']).join(', ')}",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              )),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddScheduleScreen(),
                      ),
                    );
                  },
                  child: const Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.redAccent,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Add Schedule',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 월 이동
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _goPrevMonth,
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Color(0xFFBFB69B),
                  ),
                ),
                Text(
                  '$y / ${m.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontFamily: 'Futura',
                    fontSize: 18,
                    color: Color(0xFFBFB69B),
                  ),
                ),
                IconButton(
                  onPressed: _goNextMonth,
                  icon: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFBFB69B),
                  ),
                ),
              ],
            ),
          ),

          // 날짜 리스트
          Expanded(
            child: _isLoadingMonth
                ? const Center(child: CircularProgressIndicator())
                : (_errorMonth != null
                      ? Center(
                          child: Text(
                            _errorMonth!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: lastDay,
                          itemBuilder: (context, index) {
                            final day = index + 1;
                            final weekdayLabel = _weekdayLabel(y, m, day);
                            final schedules = _monthSchedules[day] ?? [];
                            final isSat =
                                DateTime(y, m, day).weekday ==
                                DateTime.saturday;
                            final isSun =
                                DateTime(y, m, day).weekday == DateTime.sunday;
                            final color = isSun
                                ? Colors.red
                                : (isSat ? Colors.blue : Colors.black);

                            final previewTitle = schedules.isNotEmpty
                                ? (schedules.first['title'] ?? '')
                                : '';

                            return InkWell(
                              onTap: () {
                                print(
                                  "★★ tapped day=$day, schedules=$schedules",
                                );
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ModifyScheduleScreen(
                                      schedule: schedules.isNotEmpty
                                          ? schedules.first
                                          : null,
                                    ),
                                  ),
                                ).then((_) {
                                  _fetchMonth();
                                  if (_currentMonth.year == _today.year &&
                                      _currentMonth.month == _today.month) {
                                    _fetchToday();
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                ),
                                child: Container(
                                  height: _rowHeight,
                                  alignment: Alignment.centerLeft,
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(color: Colors.black12),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          text: '$day  ',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontFamily: 'Futura',
                                            color: color,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: weekdayLabel,
                                              style: TextStyle(color: color),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            previewTitle,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        )),
          ),
        ],
      ),
    );
  }
}
