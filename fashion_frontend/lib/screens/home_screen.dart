// home_screen.dart
// ★ 주석은 한국어로 작성했습니다.
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fashion_frontend/main.dart' show routeObserver;

const String kOpenWeatherApiKey = 'YOUR_OPENWEATHER_API_KEY';
const storage = FlutterSecureStorage();

// 옷 ID → 이미지 경로 변환 (임시)
String getImagePathFromId(int id) => 'assets/images/$id.jpg';

String _joinPartsEn(Iterable<String?> parts) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in parts) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) continue;
    if (seen.add(s)) out.add(s);
  }
  return out.join(', ');
}

String _conditionFromWeatherCode(int? code) {
  if (code == null) return "Unknown";
  if (code == 0) return "Clear";
  if ([1, 2, 3].contains(code)) return "Cloudy";
  if ([45, 48].contains(code)) return "Fog";
  if (code >= 51 && code <= 67) return "Rain";
  if (code >= 71 && code <= 77) return "Snow";
  if (code >= 80 && code <= 82) return "Shower";
  if ([95, 96, 99].contains(code)) return "Thunderstorm";
  return "Other";
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState(); // ← 타입 이름 맞춤
}

class HomeScreenState extends State<HomeScreen> with RouteAware {
  bool isGenerated = false;
  bool _isLoading = false;
  String _errorMessage = '';

  List<String> outfitImages = [];
  String outfitReason = 'This is an outfit suitable for a meeting.';

  List<Map<String, String>> outfitResults = [];

  // 🟢🟢🟢🟢🟢🟢🟢🟢🟢🟢🟢🟢server URL (ngrok 등으로 외부에서 접근 가능하도록 설정)🟢🟢🟢🟢🟢🟢🟢🟢🟢🟢🟢🟢
  static const String _apiUrl =
      'https://e4f221981748.ngrok-free.app/recommend_outfit';

  String _topCity = 'Locating...';
  int? _topCurrent;
  int? _topHigh;
  int? _topLow;
  int? _topCode;

  String _username = '';

  String _todayEvent = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadHomeTopWeather();
    _fetchUserName();
    _loadTodayEvent();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    debugPrint('[HomeScreen] didPopNext - refresh triggered');
    refresh();
  }

  void refresh() async {
    debugPrint("[HomeScreen] refresh() called");
    await _loadHomeTopWeather();

    final updatedEvent = await _fetchTodayEvent();
    debugPrint("[HomeScreen] updatedEvent = $updatedEvent");
    setState(() {
      _todayEvent = updatedEvent;
      isGenerated = false;
      _errorMessage = '';
      outfitResults.clear();
    });
  }

  Future<void> _loadTodayEvent() async {
    final event = await _fetchTodayEvent();
    setState(() {
      _todayEvent = event;
    });
  }

  // ---------------- 위치 ----------------
  Future<Position> _determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('location services disabled.');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('location permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('location permission permanently denied');
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  // ---------------- 도시명 ----------------
  Future<String> _resolveCityNameEn(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/reverse'
        '?latitude=$lat&longitude=$lon&language=en',
      );
      final res = await http
          .get(uri, headers: {HttpHeaders.acceptHeader: 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final j = json.decode(res.body) as Map<String, dynamic>;
        final results = (j['results'] as List?) ?? const [];
        if (results.isNotEmpty) {
          final r = results.first as Map<String, dynamic>;
          final name = _joinPartsEn([r['name'], r['admin1'], r['country']]);
          if (name.isNotEmpty) return name;
        }
      }
    } catch (_) {}
    try {
      final placemarks = await placemarkFromCoordinates(
        lat,
        lon,
      ).timeout(const Duration(seconds: 6));
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final name = _joinPartsEn([
          p.locality,
          p.administrativeArea,
          p.country,
        ]);
        if (name.isNotEmpty) return name;
      }
    } catch (_) {}
    return 'Current Location(failed)';
  }

  // ---------------- Open-Meteo 날씨 ----------------
  Future<Map<String, dynamic>> _fetchOpenMeteo(double lat, double lon) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat'
      '&longitude=$lon'
      '&current=temperature_2m,weathercode'
      '&daily=temperature_2m_max,temperature_2m_min'
      '&timezone=auto',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw Exception('weather API error');
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<void> _loadHomeTopWeather() async {
    try {
      final pos = await _determinePosition();
      final city = await _resolveCityNameEn(pos.latitude, pos.longitude);
      final data = await _fetchOpenMeteo(pos.latitude, pos.longitude);

      Map<String, dynamic> current = (data['current'] as Map)
          .cast<String, dynamic>();
      Map<String, dynamic> daily = (data['daily'] as Map)
          .cast<String, dynamic>();

      setState(() {
        _topCity = city;
        _topCurrent = (current['temperature_2m'] as num?)?.round();
        _topHigh = (daily['temperature_2m_max'] as List?)
            ?.cast<num>()
            .first
            ?.round();
        _topLow = (daily['temperature_2m_min'] as List?)
            ?.cast<num>()
            .first
            ?.round();
        _topCode = (current['weathercode'] as num?)?.toInt();
      });
    } catch (_) {
      setState(() {
        _topCity = 'Current Location(failed)';
        _topCurrent = null;
        _topHigh = null;
        _topLow = null;
        _topCode = null;
      });
    }
  }

  // ---------------- OpenWeather 현재 날씨 ----------------
  Future<Map<String, dynamic>> _getCurrentWeather() async {
    final pos = await Geolocator.getCurrentPosition();
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather'
      '?lat=${pos.latitude}&lon=${pos.longitude}'
      '&appid=$kOpenWeatherApiKey&units=metric',
    );
    final res = await http.get(url).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) throw 'Weather API error';
    final data = json.decode(res.body);
    return {
      'temperature': (data['main']?['temp'] as num?)?.toDouble(),
      'condition': (data['weather'][0]['main'] as String?),
    };
  }

  // ---------------- Django API helpers ----------------
  Future<List<Map<String, dynamic>>> _fetchCloset() async {
    final token = await storage.read(key: "access_token");
    if (token == null) return [];

    final url = Uri.parse("http://127.0.0.1:8000/api/clothes/");
    final res = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map<Map<String, dynamic>>((item) {
        final map = Map<String, dynamic>.from(item);
        // ★ custom_id を id に差し替え
        if (map.containsKey('custom_id')) {
          map['id'] = map['custom_id'];
          map.remove('custom_id'); // もし不要なら消す
          map.remove('owner');
          // map.remove('image');
        }
        return map;
      }).toList();
    } else {
      debugPrint("Failed to load closet: ${res.statusCode}");
      return [];
    }
  }

  Future<void> _fetchUserName() async {
    final token = await storage.read(key: "access_token");
    if (token == null) return;

    final url = Uri.parse("http://127.0.0.1:8000/api/auth/me/");
    final res = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        _username = data['username'] ?? '';
      });
    }
  }

  Future<String> _fetchTodayEvent() async {
    final token = await storage.read(key: "access_token");
    if (token == null) return "No schedule";
    final todayStr = DateTime.now().toIso8601String().split("T").first;
    final url = Uri.parse("http://127.0.0.1:8000/api/events/?date=$todayStr");
    final res = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );
    if (res.statusCode == 200) {
      final List events = jsonDecode(res.body);
      if (events.isEmpty) {
        debugPrint("No events found for $todayStr");
        return "No schedule";
      }
      debugPrint("Fetched event: ${events.first['title']}");
      return events.first['title'] ?? "No schedule";
    }
    debugPrint("Failed to fetch events: ${res.statusCode}");
    return "No schedule";
  }

  Future<String> _fetchUserGender() async {
    final token = await storage.read(key: "access_token");
    if (token == null) return "Unisex";

    final url = Uri.parse("http://127.0.0.1:8000/api/auth/me/");
    final res = await http.get(
      url,
      headers: {"Authorization": "Bearer $token"},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['gender'] ?? "Unisex";
    }
    return "Unisex";
  }

  // ⭐️⭐️⭐️️AIサーバー接続版⭐️⭐️⭐️
  Future<void> _getOutfitRecommendation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      isGenerated = false;
    });

    // ⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️ MOCK ここから ⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️
    bool useMockWeather = true;
    double mockTemperature = 5.0;
    String mockCondition = "Clear";

    // 실제 전송값 정의
    double sendTemp = useMockWeather
        ? mockTemperature
        : (_topCurrent ?? 22).toDouble();

    String sendCond = useMockWeather
        ? mockCondition
        : _conditionFromWeatherCode(_topCode);

    // ⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️ MOCK ここまで温度設定⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️

    // ---------------- Open-Meteo에서 화면에 표시된 현재 기온/날씨코드를 그대로 사용 ----------------
    // ⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️ した二つを注釈消したら現在気温送れる⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️⭐️
    // double sendTemp = (_topCurrent ?? 22).toDouble();
    // String sendCond = _conditionFromWeatherCode(_topCode);

    // ---------------- Closet, Event, Gender ----------------
    List<Map<String, dynamic>> closet = [];
    String event = "No schedule";
    String gender = "Unisex";

    try {
      closet = await _fetchCloset();
      event = await _fetchTodayEvent();
      gender = await _fetchUserGender();
    } catch (e) {
      debugPrint("fetch data failed: $e");
    }

    // ---------------- 전송 직전 로그 ----------------
    final closetIds = closet.map((c) => c["id"]).toList();
    print("=== Sending Data ===");

    final requestData = {
      "closet": closet,
      "event": event,
      "temperature": sendTemp,
      "condition": sendCond,
      "gender": gender,
    };
    print(
      json.encode({
        "closet": closet.isNotEmpty ? [closet.first] : [],
        "event": event,
        "temperature": sendTemp,
        "condition": sendCond,
        "gender": gender,
      }),
    );

    try {
      final res = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestData),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final body = json.decode(utf8.decode(res.bodyBytes));

        // ---------------- 응답 출력 ----------------
        print("=== API Response ===");
        print(json.encode(body));

        final bestCombo = body['best_combination'] ?? {};
        final List<dynamic> idsDyn = bestCombo['ids'] ?? [];
        final List<String> descList =
            (bestCombo['description'] as String?)
                ?.split(',')
                .map((s) => s.trim())
                .toList() ??
            [];
        final String explanation = body['explanation'] ?? "No explanation";

        final results = <Map<String, String>>[];
        for (int i = 0; i < idsDyn.length; i++) {
          final id = idsDyn[i];
          final desc = i < descList.length ? descList[i] : "";
          final matched = closet.firstWhere(
            (item) => item["id"] == id,
            orElse: () => <String, dynamic>{},
          );
          final img = matched["image"] as String? ?? "";
          results.add({"image": img, "desc": desc});
        }

        setState(() {
          outfitResults = results;
          outfitReason = explanation;
          isGenerated = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'server error: ${res.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'error: $e';
        _isLoading = false;
      });
    }
  }

  // ---------------- weathercode → 아이콘 ----------------
  IconData _iconFromWeatherCode(int? code) {
    if (code == null) return Icons.cloud_outlined;
    if (code == 0) return Icons.wb_sunny_outlined;
    if ([1, 2, 3].contains(code)) return Icons.cloud_outlined;
    if ([45, 48].contains(code)) return Icons.blur_on;
    if (code != null && code >= 51 && code <= 67) return Icons.grain;
    if (code != null && code >= 71 && code <= 77) return Icons.ac_unit;
    if (code != null && code >= 80 && code <= 82) return Icons.cloud_queue;
    if ([95, 96, 99].contains(code)) return Icons.thunderstorm;
    return Icons.wb_cloudy_outlined;
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final double yOffset = 30.0;

    return Scaffold(
      backgroundColor: const Color(0xfffbfbfb),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 200 + yOffset,
            child: Container(color: const Color(0xffbfb69b)),
          ),
          Positioned(
            top: 25 + yOffset,
            left: MediaQuery.of(context).size.width / 2 - 75,
            child: SizedBox(
              width: 150,
              child: Center(
                child: Image.asset(
                  'assets/images/outfitter_logo2.png',
                  fit: BoxFit.contain,
                  height: 60,
                ),
              ),
            ),
          ),
          Positioned(
            top: 80 + yOffset,
            left: 12,
            right: 12,
            height: 41,
            child: GestureDetector(
              onTap: () {
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).pushNamed('/weather');
              }, // /weather 화면 이동 처리 가능
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xfff9f2ed),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Color(0xffbf634e),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _topCity,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'Futura',
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _topCurrent != null ? '${_topCurrent}°C' : '—',
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'Futura',
                        color: Color(0xff0d0d0d),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _iconFromWeatherCode(_topCode),
                      size: 16,
                      color: const Color(0xffbf634e),
                    ),
                    const SizedBox(width: 12),
                    if (_topHigh != null || _topLow != null)
                      Row(
                        children: [
                          if (_topLow != null)
                            Text(
                              '${_topLow}°C',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Futura',
                                color: Color(0xffbf634e),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          if (_topHigh != null && _topLow != null)
                            const Text(
                              ' / ',
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'Futura',
                                color: Color(0xff707070),
                              ),
                            ),
                          if (_topHigh != null)
                            Text(
                              '${_topHigh}°C',
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'Futura',
                                color: Color(0xff2F67FF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 135 + yOffset,
            left: MediaQuery.of(context).size.width / 2 - 150,
            child: IgnorePointer(
              ignoring: true,
              child: Text(
                _username.isNotEmpty ? "Hello, $_username!" : "Hello!",
                style: const TextStyle(
                  fontFamily: 'Futura',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xfff9f2ed),
                ),
              ),
            ),
          ),
          Positioned(
            top: 165 + yOffset,
            left: MediaQuery.of(context).size.width / 2 - 150,
            child: Text(
              "Today’s plan : $_todayEvent",
              style: const TextStyle(
                fontFamily: 'Futura',
                fontSize: 16,
                color: Color(0xfff9f2ed),
              ),
            ),
          ),
          Positioned(
            top: 210 + yOffset,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: _getOutfitRecommendation,
              child: Center(
                child: Container(
                  width: 260,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xffbf634e),
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                  child: const Center(
                    child: Text(
                      "Generate\nToday’s Outfit",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Futura',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xfff9f2ed),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_errorMessage.isNotEmpty)
            Center(
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          if (isGenerated)
            Positioned(
              top: 300 + yOffset,
              left: 10,
              right: 10,
              child: Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: outfitResults.map((item) {
                      final imgPath = item["image"] ?? "";
                      final desc = item["desc"] ?? "";
                      final baseUrl = "http://127.0.0.1:8000";
                      final fullUrl = imgPath.startsWith("http")
                          ? imgPath
                          : "$baseUrl$imgPath";

                      return Container(
                        width: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xffe3e3e3)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              fit: FlexFit.loose,
                              child: imgPath.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(10),
                                        topRight: Radius.circular(10),
                                      ),
                                      child: Image.network(
                                        fullUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const ColoredBox(
                                              color: Color(0xFFEFEFEF),
                                              child: Center(
                                                child: Icon(
                                                  Icons.image_not_supported,
                                                ),
                                              ),
                                            ),
                                      ),
                                    )
                                  : const SizedBox(
                                      height: 145, // 他の画像と同じ高さ
                                      child: ColoredBox(
                                        color: Color(0xFFEFEFEF),
                                        child: Center(
                                          child: Icon(Icons.checkroom),
                                        ),
                                      ),
                                    ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Text(
                                desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'Futura',
                                  color: Color(0xff0D0D0D),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),
                  Text(
                    outfitReason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Futura',
                      color: Color(0xff707070),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
