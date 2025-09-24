import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AddScheduleScreen extends StatefulWidget {
  const AddScheduleScreen({super.key});

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  // ----------------- 상태 -----------------
  DateTime? _selectedDate; // 날짜 (필수)
  bool _allDay = false; // 하루종일 여부 (체크박스)
  TimeOfDay? _startTime; // 시작시간
  TimeOfDay? _endTime; // 종료시간
  final TextEditingController _planCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  bool _showErrors = false;

  static const List<String> _planOptions = [
    'Art Gallery Visit',
    'Attending a Play',
    'Baby Shower',
    'Baking Session',
    'Beach Trip',
    'Beach Volleyball',
    'Board Game Night',
    'Book Club Meeting',
    'Business Presentation',
    'Camping Trip',
    'Car Repair',
    'Casual Day Out',
    'Charity Marathon',
    'Cocktail Party',
    'Conference Attendance',
    'Cultural Festival',
    'Cruise Vacation',
    'Cycling Tour',
    'Date Night',
    'Dog Walking',
    'Evening Party',
    'Fine Dining',
    'Fishing Trip',
    'Formal Gala',
    'Game Day at Stadium',
    'Gardening',
    'Gym Workout',
    'Hiking',
    'Home Office Work',
    'Job Interview',
    'Library Study',
    'Meditation Retreat',
    'Movie Night In',
    'Morning Coffee Run',
    'Museum Visit',
    'Music Festival',
    'Neighborhood Walk',
    'Night Out with Friends',
    'Office Meeting',
    'Online Class',
    'Opera Night',
    'Outdoor Concert',
    'Picnic in Park',
    'Pottery Class',
    'Public Speaking Event',
    'Quick Grocery Run',
    'Relaxing at Home',
    'Religious Gathering',
    'Road Trip',
    'Running Errands',
    'Shopping Spree',
    'Ski Trip',
    'Street Photography',
    'Summer BBQ',
    'Traditional Ceremony',
    'Travel Day',
    'University Lecture',
    'Volunteering Event',
    'Weekend Brunch',
    'Wedding Ceremony',
    'Yoga Class',
  ];

  @override
  void dispose() {
    _planCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  bool get _isDateValid => _selectedDate != null;
  bool get _isPlanValid => _planOptions.contains(_planCtrl.text.trim());
  bool get _isTimeRangeValid {
    if (_allDay) return true;
    if (_startTime == null || _endTime == null) return true;
    final s = _startTime!.hour * 60 + _startTime!.minute;
    final e = _endTime!.hour * 60 + _endTime!.minute;
    return s <= e;
  }

  bool get _formValid => _isDateValid && _isPlanValid && _isTimeRangeValid;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
    );
    if (result != null) setState(() => _selectedDate = result);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart
          ? (_startTime ?? TimeOfDay.now())
          : (_endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    if (!_formValid) return;

    final storage = const FlutterSecureStorage();
    String? access = await storage.read(key: 'access_token');
    final refresh = await storage.read(key: 'refresh_token');

    // 날짜 문자열
    final dateStr =
        '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

    String? startTimeStr;
    String? endTimeStr;
    if (!_allDay) {
      if (_startTime != null) {
        startTimeStr =
            '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
      }
      if (_endTime != null) {
        endTimeStr =
            '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}';
      }
    }

    final body = {
      "date": dateStr,
      "all_day": _allDay,
      "start_time": startTimeStr,
      "end_time": endTimeStr,
      "title": _planCtrl.text.trim(),
      "description": _descCtrl.text.trim(),
    };

    try {
      // --- 共通で使う関数化 ---
      Future<http.Response> doPost(String? token) {
        return http.post(
          Uri.parse('http://127.0.0.1:8000/api/events/'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        );
      }

      var resp = await doPost(access);

      // 401 → refresh 처리
      if (resp.statusCode == 401 && refresh != null) {
        final refreshResp = await http.post(
          Uri.parse('http://127.0.0.1:8000/api/auth/refresh/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({"refresh": refresh}),
        );

        if (refreshResp.statusCode == 200) {
          final data = jsonDecode(refreshResp.body);
          final newAccess = data["access"];
          if (newAccess != null) {
            await storage.write(key: "access_token", value: newAccess);
            access = newAccess;
            resp = await doPost(newAccess); // 👉 再リクエスト
          }
        }
      }

      if (resp.statusCode == 201) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 실패: ${resp.statusCode}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('네트워크 오류: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _selectedDate == null ? '' : _formatDate(_selectedDate!);
    final startText = _startTime == null ? '' : _formatTime(_startTime!);
    final endText = _endTime == null ? '' : _formatTime(_endTime!);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFBFB69B),
        title: const Text(
          'Add New Schedule',
          style: TextStyle(
            fontFamily: 'Futura',
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: Color(0xFFF9F2ED),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35.0),
        child: ListView(
          children: [
            const SizedBox(height: 30),
            const _LabelText('Date'),
            _StyledInput(
              child: InkWell(
                onTap: _pickDate,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_note),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          dateText.isEmpty ? 'Select a date' : dateText,
                          style: TextStyle(
                            color: dateText.isEmpty
                                ? Colors.black45
                                : Colors.black87,
                          ),
                        ),
                      ),
                      const Icon(Icons.calendar_today, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            if (_showErrors && !_isDateValid)
              const _ErrorText('Please select a date.'),

            const SizedBox(height: 25),
            // Time + All-day checkbox
            Row(
              children: [
                const _LabelText('Time'),
                const Spacer(),
                const Text('All-day'),
                Checkbox(
                  value: _allDay,
                  onChanged: (v) => setState(() => _allDay = v ?? false),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _StyledInput(
                    child: InkWell(
                      onTap: _allDay ? null : () => _pickTime(isStart: true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Text(
                          startText.isEmpty ? 'Start (optional)' : startText,
                          style: TextStyle(
                            color: _allDay
                                ? Colors.black26
                                : (startText.isEmpty
                                      ? Colors.black45
                                      : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('ー'),
                ),
                Expanded(
                  child: _StyledInput(
                    child: InkWell(
                      onTap: _allDay ? null : () => _pickTime(isStart: false),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Text(
                          endText.isEmpty ? 'End (optional)' : endText,
                          style: TextStyle(
                            color: _allDay
                                ? Colors.black26
                                : (endText.isEmpty
                                      ? Colors.black45
                                      : Colors.black87),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_showErrors && !_isTimeRangeValid)
              const _ErrorText(
                'Start time must be before or equal to end time.',
              ),

            const SizedBox(height: 25),
            const _LabelText('Plan detail'),
            _StyledInput(
              height: 56,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Autocomplete<String>(
                  optionsBuilder: (TextEditingValue value) {
                    final q = value.text.trim().toLowerCase();
                    if (q.isEmpty) return _planOptions;
                    return _planOptions.where(
                      (o) => o.toLowerCase().contains(q),
                    );
                  },
                  onSelected: (selection) {
                    _planCtrl.text = selection;
                    setState(() {});
                  },
                  fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                    controller.addListener(() {
                      _planCtrl.value = controller.value;
                      setState(() {});
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search & select…',
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_showErrors && !_isPlanValid)
              const _ErrorText('Please choose from the list.'),

            const SizedBox(height: 25),
            const _LabelText('Description'),
            _StyledInput(
              height: 120,
              child: TextFormField(
                controller: _descCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(10),
                ),
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              onPressed: _formValid
                  ? _save
                  : () => setState(() => _showErrors = true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBF634E),
                minimumSize: const Size(double.infinity, 60),
                disabledBackgroundColor: const Color(
                  0xFFBF634E,
                ).withOpacity(0.5),
              ),
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelText extends StatelessWidget {
  final String label;
  const _LabelText(this.label);
  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String text;
  const _ErrorText(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, style: const TextStyle(color: Colors.red)),
    );
  }
}

class _StyledInput extends StatelessWidget {
  final Widget? child;
  final double height;
  const _StyledInput({this.child, this.height = 50});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF707070)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
