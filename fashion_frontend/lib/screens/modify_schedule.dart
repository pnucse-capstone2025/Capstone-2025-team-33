import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiConfig {
  static const String baseUrl = 'http://127.0.0.1:8000';
  static const String eventsEndpoint = '/api/events/';
}

class ModifyScheduleScreen extends StatefulWidget {
  final Map<String, dynamic>? schedule;
  final int? scheduleId;
  final DateTime? initialDate;

  const ModifyScheduleScreen({
    super.key,
    this.schedule,
    this.scheduleId,
    this.initialDate,
  });

  @override
  State<ModifyScheduleScreen> createState() => _ModifyScheduleScreenState();
}

class _ModifyScheduleScreenState extends State<ModifyScheduleScreen> {
  bool _initialLoading = true;
  bool _saving = false;
  bool _deleting = false;
  bool _showErrors = false;

  DateTime? _selectedDate;
  bool _allDay = false;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final TextEditingController _planCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();

  int? _entityId;
  Map<String, dynamic>? _initialSnapshot;

  static const List<String> _planOptions = [
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
  void initState() {
    super.initState();
    print("★★ initState called");
    if (widget.schedule != null) {
      print("★★ received schedule: ${widget.schedule}");
      _applyEntityToForm(widget.schedule!);
      _entityId = widget.schedule!['id'] as int?;
      _initialSnapshot = _currentSnapshot();
      _initialLoading = false;
    } else {
      _loadSchedule();
    }
  }

  @override
  void dispose() {
    _planCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Widget _buildPlanDetailInput() {
    return _StyledInput(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Autocomplete<String>(
          optionsBuilder: (TextEditingValue value) {
            final q = value.text.trim().toLowerCase();
            if (q.isEmpty) return _planOptions;
            return _planOptions.where((o) => o.toLowerCase().contains(q));
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
          initialValue: TextEditingValue(text: _planCtrl.text),
        ),
      ),
    );
  }

  // ---- formatter ----
  String _formatDate(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  String _toIsoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ---- validation ----
  bool get _isDateValid => _selectedDate != null;
  bool get _isPlanValid => _planCtrl.text.trim().isNotEmpty;
  bool get _isTimeRangeValid {
    if (_allDay) return true;
    if (_startTime == null || _endTime == null) return true;
    final s = _startTime!.hour * 60 + _startTime!.minute;
    final e = _endTime!.hour * 60 + _endTime!.minute;
    return s <= e;
  }

  bool get _formValid => _isDateValid && _isPlanValid && _isTimeRangeValid;

  // ---- snapshot ----
  Map<String, dynamic> _currentSnapshot() {
    String? st;
    String? et;
    if (!_allDay) {
      if (_startTime != null) {
        st =
            '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
      }
      if (_endTime != null) {
        et =
            '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}';
      }
    }
    return {
      'date': _selectedDate != null ? _toIsoDate(_selectedDate!) : null,
      'all_day': _allDay,
      'start_time': st,
      'end_time': et,
      'title': _planCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
    };
  }

  bool get _isDirty {
    if (_initialSnapshot == null) return false;
    final now = _currentSnapshot();
    for (final k in _initialSnapshot!.keys) {
      if (_initialSnapshot![k] != now[k]) return true;
    }
    return false;
  }

  // ---- load ----
  Future<void> _loadSchedule() async {
    setState(() => _initialLoading = true);
    try {
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: "access_token");
      if (widget.scheduleId != null) {
        final uri = Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.eventsEndpoint}${widget.scheduleId}/',
        );
        final resp = await http.get(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        );
        if (resp.statusCode == 200) {
          final entity = jsonDecode(resp.body) as Map<String, dynamic>;
          _applyEntityToForm(entity);
          _initialSnapshot = _currentSnapshot();
        }
      } else if (widget.initialDate != null) {
        final dateStr = _toIsoDate(widget.initialDate!);
        final uri = Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.eventsEndpoint}?date=$dateStr',
        );
        final resp = await http.get(
          uri,
          headers: {'Authorization': 'Bearer $token'},
        );
        if (resp.statusCode == 200) {
          final list = jsonDecode(resp.body) as List;
          if (list.isNotEmpty) {
            final entity = Map<String, dynamic>.from(list.first);
            _applyEntityToForm(entity);
            _initialSnapshot = _currentSnapshot();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Load error: $e')));
      }
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  void _applyEntityToForm(Map<String, dynamic> entity) {
    _entityId = entity['id'] as int?;

    final dateStr = (entity['date'] ?? '') as String;
    if (dateStr.isNotEmpty) {
      final parts = dateStr
          .split('-')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      if (parts.length == 3) {
        _selectedDate = DateTime(parts[0], parts[1], parts[2]);
      }
    }

    _allDay = (entity['all_day'] ?? false) as bool;
    _startTime = (entity['start_time'] != null && entity['start_time'] != "")
        ? _parseTimeOfDay(entity['start_time'])
        : null;
    _endTime = (entity['end_time'] != null && entity['end_time'] != "")
        ? _parseTimeOfDay(entity['end_time'])
        : null;

    _planCtrl.text = (entity['title'] ?? '').toString(); // ★ title に統一
    _descCtrl.text = (entity['description'] ?? '').toString();

    setState(() {});
  }

  TimeOfDay _parseTimeOfDay(String hhmm) {
    final sp = hhmm.split(':');
    final h = int.tryParse(sp[0]) ?? 0;
    final m = int.tryParse(sp.length > 1 ? sp[1] : '0') ?? 0;
    return TimeOfDay(hour: h, minute: m);
  }

  // ---- pickers ----
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
    if (_allDay) return;
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

  // ---- save/delete ----
  Map<String, dynamic> _buildPayload() {
    String? st;
    String? et;
    if (!_allDay) {
      if (_startTime != null) {
        st =
            '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
      }
      if (_endTime != null) {
        et =
            '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}';
      }
    }
    final dateStr = _selectedDate != null ? _toIsoDate(_selectedDate!) : null;
    return {
      'date': dateStr,
      'all_day': _allDay,
      'start_time': st,
      'end_time': et,
      'title': _planCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
    };
  }

  Future<void> _save() async {
    setState(() => _showErrors = true);
    if (!_formValid) return;
    if (_entityId == null) return;

    setState(() => _saving = true);
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.eventsEndpoint}$_entityId/',
      );
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: "access_token");
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final resp = await http.put(
        uri,
        headers: headers,
        body: jsonEncode(_buildPayload()),
      );
      if (resp.statusCode == 200) {
        _initialSnapshot = _currentSnapshot();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Saved successfully.')));
          Navigator.pop(context, true);
        }
      } else {
        throw Exception("Failed: ${resp.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (_entityId == null) return;
    setState(() => _deleting = true);
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.eventsEndpoint}$_entityId/',
      );
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: "access_token");
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final resp = await http.delete(uri, headers: headers);
      if (resp.statusCode == 204) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deleted successfully.')),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: ${resp.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete error: $e')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  // ---- confirm ----
  Future<bool> _confirmDiscardIfDirty() async {
    if (!_isDirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('Do you want to close without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _confirmDelete() async {
    if (_entityId == null) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('Are you sure you want to delete this content?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (result == true) await _delete();
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => await _confirmDiscardIfDirty(),
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFFBFB69B),
          title: const Text(
            'Modify Schedule',
            style: TextStyle(
              fontFamily: 'Futura',
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: Color(0xFFF9F2ED),
            ),
          ),
          actions: [
            IconButton(
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleting ? null : _confirmDelete,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _saving || _deleting
                  ? null
                  : () async {
                      final ok = await _confirmDiscardIfDirty();
                      if (ok && mounted) Navigator.pop(context, false);
                    },
            ),
          ],
        ),
        body: _initialLoading
            ? const Center(child: CircularProgressIndicator())
            : AbsorbPointer(
                absorbing: _saving || _deleting,
                child: Padding(
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
                                    _selectedDate == null
                                        ? 'Select a date'
                                        : _formatDate(_selectedDate!),
                                    style: TextStyle(
                                      color: _selectedDate == null
                                          ? Colors.black45
                                          : Colors.black87,
                                      fontSize: 16,
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
                      Row(
                        children: [
                          const _LabelText('Time'),
                          const Spacer(),
                          const Text('All-day'),
                          Checkbox(
                            value: _allDay,
                            onChanged: (v) =>
                                setState(() => _allDay = v ?? false),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _StyledInput(
                              child: InkWell(
                                onTap: _allDay
                                    ? null
                                    : () => _pickTime(isStart: true),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    _startTime == null
                                        ? 'Start (optional)'
                                        : _formatTime(_startTime!),
                                    style: TextStyle(
                                      color: _allDay
                                          ? Colors.black26
                                          : (_startTime == null
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
                                onTap: _allDay
                                    ? null
                                    : () => _pickTime(isStart: false),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    _endTime == null
                                        ? 'End (optional)'
                                        : _formatTime(_endTime!),
                                    style: TextStyle(
                                      color: _allDay
                                          ? Colors.black26
                                          : (_endTime == null
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
                      _buildPlanDetailInput(),
                      if (_showErrors && !_isPlanValid)
                        const _ErrorText('Please input a title.'),
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
                        onPressed: (_formValid && !_saving && !_deleting)
                            ? _save
                            : () => setState(() => _showErrors = true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFBF634E),
                          disabledBackgroundColor: const Color(
                            0xFFBF634E,
                          ).withOpacity(0.5),
                          minimumSize: const Size(double.infinity, 60),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                              ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
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
      style: const TextStyle(
        fontFamily: 'Futura',
        fontWeight: FontWeight.w500,
        fontSize: 20,
        color: Color(0xFF0D0D0D),
      ),
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
        color: const Color(0xFFFFFFFF),
        border: Border.all(color: const Color(0xFF707070)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
