// weather_screen.dart
// ★ 주석은 한국어로 작성했습니다.
import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart'; // ★ 실패 시 포fallback 역지오코딩

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  // ----------------------------- 색/스타일 상수 -----------------------------
  static const Color primary = Color(0xFFBFB69B); // 상단 배경
  static const Color cardBg = Color(0xFFF9F2ED);
  static const Color cardBgAlt = Color(0xFFF3F0EC);
  static const Color textMain = Color(0xFF0D0D0D);
  static const Color textSub = Color(0xFF707070);
  static const Color accentRed = Color(0xFFBF634E);
  static const Color accentBlue = Color(0xFF2F67FF);

  // ----------------------------- 상태 -----------------------------
  // ★ 시간별 데이터 (시각/아이콘/온도/강수확률)
  List<Map<String, dynamic>> _hourly = [];

  // ★ 요약 정보 (도시/현재/최고/최저/체감/습도/UV/풍속/일출/일몰)
  Map<String, dynamic> _summary = {
    'city': 'Locating...',
    'current': null,
    'high': null,
    'low': null,
    'feelsLike': null,
    'humidity': null,
    'uv': null,
    'wind': null, // m/s
    'sunrise': '-',
    'sunset': '-',
  };

  // ★ 가로 스크롤 1개 (열 동기)
  final ScrollController _hScrollCtrl = ScrollController();

  bool _loading = true;
  String? _error;

  // ★ 최신 좌표 디버그용 저장
  Position? _lastPos;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  @override
  void dispose() {
    _hScrollCtrl.dispose();
    super.dispose();
  }

  // ----------------------------- 유틸: 문자열 병합 -----------------------------
  /// ★ 공백/Null이 아닌 문자열만 모아서 중복 제거 후 ", "로 합치기
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

  // ----------------------------- 도시명 해석 (영문 고정) -----------------------------
  /// ★ ① Open-Meteo Reverse Geocoding API → ② 실패 시 geocoding 패키지로 fallback
  Future<String> _resolveCityNameEn({
    required double lat,
    required double lon,
  }) async {
    // ---- ① Open-Meteo 우선 시도
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
          final name = _joinPartsEn([
            r['name'] as String?, // 예: Seoul
            r['admin1'] as String?, // 예: Seoul
            r['country'] as String?, // 예: South Korea
          ]);
          if (name.trim().isNotEmpty) {
            return name;
          }
        } else {
          // ★ 결과가 빈 배열인 경우 (해양/좌표 오차 등)
          debugPrint('[reverse] Open-Meteo results empty for $lat,$lon');
        }
      } else {
        debugPrint(
          '[reverse] Open-Meteo status ${res.statusCode} body=${res.body}',
        );
      }
    } catch (e) {
      debugPrint('[reverse] Open-Meteo error: $e');
    }

    // ---- ② geocoding 패키지 fallback (영문 로케일로 요청)
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final name = _joinPartsEn([
          p.locality,
          p.administrativeArea,
          p.country,
        ]);
        if (name.trim().isNotEmpty) {
          return name;
        }
      }
    } catch (e) {
      debugPrint('[reverse] geocoding error: $e');
    }

    // ---- ③ 최종 실패
    return 'Current Location(failed)'; // ★ 실패 시
  }

  // ----------------------------- 위치 + 날씨 로딩 -----------------------------
  Future<void> _loadWeather() async {
    try {
      // 1) 위치 권한 확인/요청
      final pos = await _determinePosition();
      _lastPos = pos; // 디버그 표시용
      debugPrint(
        '[geo] got position lat=${pos.latitude}, lon=${pos.longitude}',
      );

      // 2) ★ 도시명 (영문) 해석 — Open-Meteo ↔ geocoding fallback
      final city = await _resolveCityNameEn(
        lat: pos.latitude,
        lon: pos.longitude,
      );
      debugPrint('[geo] resolved city: $city');

      // 3) 날씨 API 호출 (무료/키 불필요)
      final data = await _fetchOpenMeteo(lat: pos.latitude, lon: pos.longitude);

      // 4) JSON 파싱 → 화면 상태로 변환 (영문 도시명 반영)
      _applyWeatherJson(data, cityName: city);

      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      // 오류 처리: 권한 거부/오프라인 등
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ----------------------------- 위치 권한/설정 확인 -----------------------------
  Future<Position> _determinePosition() async {
    // 서비스 켜짐 여부
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('位置情報サービスが無効です（端末の設定で有効にしてください）');
    }

    // 권한 상태 확인
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('位置情報の権限が拒否されました');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('位置情報の権限が永久に拒否されています（設定から許可が必要）');
    }

    // 현재 위치
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  // ----------------------------- Open-Meteo 호출 -----------------------------
  Future<Map<String, dynamic>> _fetchOpenMeteo({
    required double lat,
    required double lon,
  }) async {
    // 참고: weathercode / precipitation_probability / temperature_2m
    // current: temperature_2m, relative_humidity_2m, weathercode, wind_speed_10m
    // daily: temperature_2m_max, temperature_2m_min, sunrise, sunset, uv_index_max
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat'
      '&longitude=$lon'
      '&hourly=temperature_2m,precipitation_probability,weathercode'
      '&current=temperature_2m,relative_humidity_2m,weathercode,wind_speed_10m'
      '&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max'
      '&timezone=auto',
    );

    final res = await http
        .get(uri, headers: {HttpHeaders.acceptHeader: 'application/json'})
        .timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) {
      throw Exception('天気APIの呼び出しに失敗しました（${res.statusCode}）');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  // ----------------------------- JSON → 상태 반영 -----------------------------
  // ★ Open-Meteo JSON → 화면 표시용 데이터로 변환 (+ 24시간 슬라이싱)
  void _applyWeatherJson(
    Map<String, dynamic> jsonMap, {
    required String cityName,
  }) {
    // ★ 안전하게 Map에서 값 꺼내기
    T? pick<T>(Map<String, dynamic> m, String k) =>
        (m[k] is T) ? m[k] as T : null;

    // ---- 현재/시간별/일별 데이터 분리
    final current = pick<Map<String, dynamic>>(jsonMap, 'current') ?? {};
    final hourly = pick<Map<String, dynamic>>(jsonMap, 'hourly') ?? {};
    final daily = pick<Map<String, dynamic>>(jsonMap, 'daily') ?? {};

    // ---- 현재값
    final currTemp = (current['temperature_2m'] as num?)?.toDouble(); // 현재 기온
    final currHumidity = (current['relative_humidity_2m'] as num?)
        ?.toInt(); // 현재 습도
    final currWind = (current['wind_speed_10m'] as num?)?.toDouble(); // 현재 풍속

    // ---- 일일값
    final dailyMaxList =
        (daily['temperature_2m_max'] as List?)?.cast<num>() ?? const [];
    final dailyMinList =
        (daily['temperature_2m_min'] as List?)?.cast<num>() ?? const [];
    final sunriseList = (daily['sunrise'] as List?)?.cast<String>() ?? const [];
    final sunsetList = (daily['sunset'] as List?)?.cast<String>() ?? const [];
    final uvMaxList = (daily['uv_index_max'] as List?)?.cast<num>() ?? const [];

    // ★ 첫째 날 데이터만 사용
    final high = dailyMaxList.isNotEmpty ? dailyMaxList.first.round() : null;
    final low = dailyMinList.isNotEmpty ? dailyMinList.first.round() : null;
    final sunrise = sunriseList.isNotEmpty
        ? sunriseList.first.substring(11, 16)
        : '-';
    final sunset = sunsetList.isNotEmpty
        ? sunsetList.first.substring(11, 16)
        : '-';
    final uv = uvMaxList.isNotEmpty ? uvMaxList.first.round() : null;

    // ---- 시간별 값
    final timeList = (hourly['time'] as List?)?.cast<String>() ?? const [];
    final tempList =
        (hourly['temperature_2m'] as List?)?.cast<num>() ?? const [];
    final popList =
        (hourly['precipitation_probability'] as List?)?.cast<num>() ?? const [];
    final codeList = (hourly['weathercode'] as List?)?.cast<num>() ?? const [];

    // ---- 현재 시각 기준 시작 인덱스 계산 (정시 매칭 또는 직전시각)
    final now = DateTime.now();
    int startIndex = 0;
    for (int i = 0; i < timeList.length; i++) {
      final t = DateTime.tryParse(timeList[i]);
      if (t != null && t.hour == now.hour && t.minute == 0) {
        startIndex = i;
        break;
      }
      if (t != null && t.isBefore(now)) {
        startIndex = i;
      }
    }

    // ---- 24시간만 슬라이싱
    final endIndex = (startIndex + 24 <= timeList.length)
        ? startIndex + 24
        : timeList.length;

    // ---- 화면용 리스트 생성
    final List<Map<String, dynamic>> rows = [];
    for (int i = startIndex; i < endIndex; i++) {
      final hhmm = timeList[i].length >= 16
          ? timeList[i].substring(11, 16)
          : timeList[i];
      final code = i < codeList.length ? codeList[i].toInt() : 0;
      rows.add({
        'hour': hhmm, // 시각
        'icon': _iconFromWeatherCode(code), // 날씨 아이콘
        'temp': i < tempList.length ? tempList[i].round() : null, // 온도
        'pop': i < popList.length ? popList[i].toInt() : null, // 강수확률
      });
    }

    // ---- 상태 업데이트
    _summary = {
      'city': cityName, // ★ 영문 도시명 반영
      'current': currTemp?.round(),
      'high': high,
      'low': low,
      'feelsLike': currTemp?.round(), // 간단히 현재 기온 사용
      'humidity': currHumidity,
      'uv': uv,
      'wind': currWind,
      'sunrise': sunrise,
      'sunset': sunset,
    };
    _hourly = rows;
  }

  // ----------------------------- weathercode → 아이콘 -----------------------------
  IconData _iconFromWeatherCode(int code) {
    // 참고: https://open-meteo.com/ (weathercode 표)
    // 0: 맑음, 1~3: 대체로 맑음/부분적 구름, 45/48: 안개, 51~67: 이슬비/비,
    // 71~77: 눈, 80~82: 소나기, 95/96/99: 뇌우
    if (code == 0) return Icons.wb_sunny_outlined;
    if (code == 1 || code == 2 || code == 3) return Icons.cloud_outlined;
    if (code == 45 || code == 48) return Icons.blur_on; // 안개 대체 아이콘
    if (code >= 51 && code <= 67) return Icons.grain; // 이슬비/비
    if (code >= 71 && code <= 77) return Icons.ac_unit; // 눈
    if (code >= 80 && code <= 82) return Icons.cloud_queue; // 소나기
    if (code == 95 || code == 96 || code == 99) return Icons.thunderstorm; // 뇌우
    return Icons.wb_cloudy_outlined;
  }

  // ----------------------------- UI -----------------------------
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: primary,
      padding: const EdgeInsets.only(top: 52, left: 12, right: 12, bottom: 10),
      child: Row(
        children: const [
          _BackButtonWhite(),
          Spacer(),
          Text(
            'Weather',
            style: TextStyle(
              fontSize: 18,
              fontFamily: 'Futura',
              color: Colors.white,
            ),
          ),
          Spacer(),
          SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildLocationAndHL() {
    // ★ 디버그용 좌표 문자열
    final coord = (_lastPos == null)
        ? ''
        : ' (${_lastPos!.latitude.toStringAsFixed(4)}, ${_lastPos!.longitude.toStringAsFixed(4)})';

    return Container(
      color: primary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // ------------------ 위치명 ------------------
          Row(
            children: [
              const Text(
                'Current location ',
                style: TextStyle(
                  fontFamily: 'Futura',
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              const Icon(Icons.location_on, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${_summary['city']?.toString() ?? '-'}$coord',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Futura',
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ------------------ 최고 / 최저 / 체감 ------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 최고
              const Icon(Icons.thermostat, color: accentRed, size: 18),
              Text(
                ' ${_summary['high'] ?? '-'}°C ',
                style: const TextStyle(
                  color: accentRed,
                  fontFamily: 'Futura',
                  fontSize: 16,
                ),
              ),
              const Text(
                ' / ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Futura',
                ),
              ),
              // 최저
              const Icon(Icons.ac_unit, color: accentBlue, size: 18),
              Text(
                ' ${_summary['low'] ?? '-'}°C',
                style: const TextStyle(
                  color: accentBlue,
                  fontFamily: 'Futura',
                  fontSize: 16,
                ),
              ),

              const SizedBox(width: 12),

              // feels like
              Text(
                'feels like: ${_summary['feelsLike'] ?? '-'}°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Futura',
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ----------------------------- ★ 열 단위 동기 스크롤 테이블 -----------------------------
  Widget _buildHourlyTable() {
    const double leftColW = 112; // 라벨 고정 폭
    const double colW = 72; // 각 시간 열의 폭
    const double gap = 12; // 열 간 간격
    const double rowGap = 10; // 행 간 간격

    List<Widget> _buildHourColumns() {
      return List.generate(_hourly.length, (i) {
        final h = _hourly[i];
        return Padding(
          padding: EdgeInsets.only(right: i == _hourly.length - 1 ? 0 : gap),
          child: SizedBox(
            width: colW,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 시각
                Text(
                  (h['hour'] ?? '-') as String,
                  style: const TextStyle(
                    fontFamily: 'Futura',
                    color: textSub,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: rowGap),
                // 날씨 아이콘
                Icon(
                  (h['icon'] as IconData?) ?? Icons.wb_cloudy_outlined,
                  color: accentRed,
                  size: 26,
                ),
                SizedBox(height: rowGap),
                // 온도
                Text(
                  h['temp'] != null ? '${h['temp']}°C' : '-',
                  style: const TextStyle(
                    fontFamily: 'Futura',
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                ),
                SizedBox(height: rowGap),
                // 강수확률
                Text(
                  h['pop'] != null ? '${h['pop']}%' : '-',
                  style: const TextStyle(fontFamily: 'Futura', color: textMain),
                ),
              ],
            ),
          ),
        );
      });
    }

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: cardBgAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 좌측 라벨 열 (고정)
              SizedBox(
                width: 112,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: const [
                    Text(
                      'Time',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Futura',
                        color: textSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Weather',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Futura', color: textSub),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Temperature',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Futura', color: textSub),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Chance of\nprecipitation',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Futura', color: textSub),
                    ),
                  ],
                ),
              ),
              // 우측: 시간별 열의 단일 가로 스크롤
              Expanded(
                child: SingleChildScrollView(
                  controller: _hScrollCtrl,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildHourColumns(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTripleCards() {
    return Row(
      children: [
        Expanded(
          child: _MiniCard(
            icon: Icons.water_drop_outlined,
            title: 'humidity',
            valueKey: 'humidity',
            suffix: '%',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniCard(
            icon: Icons.wb_sunny_outlined,
            title: 'UV index',
            valueKey: 'uv',
            suffix: '',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MiniCard(
            icon: Icons.air,
            title: 'wind speed',
            valueKey: 'wind',
            suffix: ' m/s',
          ),
        ),
      ],
    );
  }

  Widget _buildSunBar() {
    return Container(
      decoration: BoxDecoration(
        color: cardBgAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.wb_twilight, color: accentRed), // ★ 아이콘명 오타 수정
          const SizedBox(width: 8),
          Text(
            'sunrise ${_summary['sunrise']}',
            style: const TextStyle(fontFamily: 'Futura', color: textMain),
          ),
          const Spacer(),
          const Icon(Icons.nightlight_round, color: accentBlue),
          const SizedBox(width: 8),
          Text(
            'sunset ${_summary['sunset']}',
            style: const TextStyle(fontFamily: 'Futura', color: textMain),
          ),
        ],
      ),
    );
  }

  // ----------------------------- build -----------------------------
  @override
  Widget build(BuildContext context) {
    final isError = _error != null;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildLocationAndHL(),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (isError)
              Container(
                width: double.infinity,
                color: Colors.red.withOpacity(0.08),
                padding: const EdgeInsets.all(12),
                child: Text(
                  'エラー: ${_error!}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Column(
                  children: [
                    _buildHourlyTable(),
                    const SizedBox(height: 12),
                    _buildTripleCards(),
                    const SizedBox(height: 12),
                    _buildSunBar(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------- 보조 위젯 -----------------------------
class _BackButtonWhite extends StatelessWidget {
  const _BackButtonWhite();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.maybePop(context),
      child: const Icon(Icons.arrow_back, color: Colors.white),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String valueKey;
  final String suffix;

  const _MiniCard({
    required this.icon,
    required this.title,
    required this.valueKey,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorStateOfType<_WeatherScreenState>();
    final summary = state?._summary ?? const {};
    final raw = summary[valueKey];
    final value = raw == null ? '-' : raw.toString();

    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: _WeatherScreenState.cardBgAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: _WeatherScreenState.textSub),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Futura',
                    fontSize: 13,
                    color: _WeatherScreenState.textSub,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$value$suffix',
                  style: const TextStyle(
                    fontFamily: 'Futura',
                    fontWeight: FontWeight.w600,
                    color: _WeatherScreenState.textMain,
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

// // weather_screen.dart
// // ★ 주석은 한국어로 작성했습니다.
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:geolocator/geolocator.dart';

// class WeatherScreen extends StatefulWidget {
//   const WeatherScreen({super.key});

//   @override
//   State<WeatherScreen> createState() => _WeatherScreenState();
// }

// class _WeatherScreenState extends State<WeatherScreen> {
//   // ----------------------------- 색/스타일 상수 -----------------------------
//   static const Color primary = Color(0xFFBFB69B); // 상단 배경
//   static const Color cardBg = Color(0xFFF9F2ED);
//   static const Color cardBgAlt = Color(0xFFF3F0EC);
//   static const Color textMain = Color(0xFF0D0D0D);
//   static const Color textSub = Color(0xFF707070);
//   static const Color accentRed = Color(0xFFBF634E);
//   static const Color accentBlue = Color(0xFF2F67FF);

//   // ----------------------------- 상태 -----------------------------
//   // ★ 시간별 데이터 (시각/아이콘/온도/강수확률)
//   List<Map<String, dynamic>> _hourly = [];

//   // ★ 요약 정보 (도시/현재/최고/최저/체감/습도/UV/풍속/일출/일몰)
//   Map<String, dynamic> _summary = {
//     'city': 'Locating...',
//     'current': null,
//     'high': null,
//     'low': null,
//     'feelsLike': null,
//     'humidity': null,
//     'uv': null,
//     'wind': null, // m/s
//     'sunrise': '-',
//     'sunset': '-',
//   };

//   // ★ 가로 스크롤 1개 (열 동기)
//   final ScrollController _hScrollCtrl = ScrollController();

//   bool _loading = true;
//   String? _error;

//   @override
//   void initState() {
//     super.initState();
//     _loadWeather();
//   }

//   @override
//   void dispose() {
//     _hScrollCtrl.dispose();
//     super.dispose();
//   }

//   // ----------------------------- 유틸: 문자열 병합 -----------------------------
//   /// ★ 공백/Null이 아닌 문자열만 모아서 중복 제거 후 ", "로 합치기
//   String _joinPartsEn(Iterable<String?> parts) {
//     final seen = <String>{};
//     final out = <String>[];
//     for (final raw in parts) {
//       final s = (raw ?? '').trim();
//       if (s.isEmpty) continue;
//       if (seen.add(s)) out.add(s);
//     }
//     return out.join(', ');
//   }

//   // ----------------------------- 도시명 해석 (영문 고정) -----------------------------
//   /// ★ Open‑Meteo Reverse Geocoding API로 영문 도시명 해석
//   Future<String> _resolveCityNameEn({
//     required double lat,
//     required double lon,
//   }) async {
//     try {
//       final uri = Uri.parse(
//         'https://geocoding-api.open-meteo.com/v1/reverse'
//         '?latitude=$lat&longitude=$lon&language=en',
//       );
//       final res = await http.get(uri);
//       if (res.statusCode == 200) {
//         final j = json.decode(res.body) as Map<String, dynamic>;
//         final results = (j['results'] as List?) ?? const [];
//         if (results.isNotEmpty) {
//           final r = results.first as Map<String, dynamic>;
//           final name = _joinPartsEn([
//             r['name'] as String?, // 예: Busan
//             r['admin1'] as String?, // 예: Busan
//             r['country'] as String?, // 예: South Korea
//           ]);
//           if (name.trim().isNotEmpty) return name;
//         }
//       }
//     } catch (_) {
//       // 네트워크 오류 등은 아래 기본값으로 처리
//     }
//     return 'Current Location(failed)'; // ★ 실패 시
//   }

//   // ----------------------------- 위치 + 날씨 로딩 -----------------------------
//   Future<void> _loadWeather() async {
//     try {
//       // 1) 위치 권한 확인/요청
//       final pos = await _determinePosition();

//       // 2) ★ 도시명 (영문) 해석 — Open‑Meteo 역지오코딩 고정
//       final city = await _resolveCityNameEn(
//         lat: pos.latitude,
//         lon: pos.longitude,
//       );

//       // 3) 날씨 API 호출 (무료/키 불필요)
//       final data = await _fetchOpenMeteo(lat: pos.latitude, lon: pos.longitude);

//       // 4) JSON 파싱 → 화면 상태로 변환 (영문 도시명 반영)
//       _applyWeatherJson(data, cityName: city);

//       setState(() {
//         _loading = false;
//         _error = null;
//       });
//     } catch (e) {
//       // 오류 처리: 권한 거부/오프라인 등
//       setState(() {
//         _loading = false;
//         _error = e.toString();
//       });
//     }
//   }

//   // ----------------------------- 위치 권한/설정 확인 -----------------------------
//   Future<Position> _determinePosition() async {
//     // 서비스 켜짐 여부
//     final serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       throw Exception('位置情報サービスが無効です（端末の設定で有効にしてください）');
//     }

//     // 권한 상태 확인
//     var permission = await Geolocator.checkPermission();

//     if (permission == LocationPermission.denied) {
//       permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied) {
//         throw Exception('位置情報の権限が拒否されました');
//       }
//     }

//     if (permission == LocationPermission.deniedForever) {
//       throw Exception('位置情報の権限が永久に拒否されています（設定から許可が必要）');
//     }

//     // 현재 위치
//     return Geolocator.getCurrentPosition(
//       desiredAccuracy: LocationAccuracy.best,
//     );
//   }

//   // ----------------------------- Open‑Meteo 호출 -----------------------------
//   Future<Map<String, dynamic>> _fetchOpenMeteo({
//     required double lat,
//     required double lon,
//   }) async {
//     // 참고: weathercode / precipitation_probability / temperature_2m
//     // current: temperature_2m, relative_humidity_2m, weathercode, wind_speed_10m
//     // daily: temperature_2m_max, temperature_2m_min, sunrise, sunset, uv_index_max
//     final uri = Uri.parse(
//       'https://api.open-meteo.com/v1/forecast'
//       '?latitude=$lat'
//       '&longitude=$lon'
//       '&hourly=temperature_2m,precipitation_probability,weathercode'
//       '&current=temperature_2m,relative_humidity_2m,weathercode,wind_speed_10m'
//       '&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max'
//       '&timezone=auto',
//     );

//     final res = await http.get(uri);
//     if (res.statusCode != 200) {
//       throw Exception('天気APIの呼び出しに失敗しました（${res.statusCode}）');
//     }
//     return json.decode(res.body) as Map<String, dynamic>;
//   }

//   // ----------------------------- JSON → 상태 반영 -----------------------------
//   // ★ Open-Meteo JSON → 화면 표시용 데이터로 변환 (+ 24시간 슬라이싱)
//   void _applyWeatherJson(
//     Map<String, dynamic> jsonMap, {
//     required String cityName,
//   }) {
//     // ★ 안전하게 Map에서 값 꺼내기
//     T? pick<T>(Map<String, dynamic> m, String k) =>
//         (m[k] is T) ? m[k] as T : null;

//     // ---- 현재/시간별/일별 데이터 분리
//     final current = pick<Map<String, dynamic>>(jsonMap, 'current') ?? {};
//     final hourly = pick<Map<String, dynamic>>(jsonMap, 'hourly') ?? {};
//     final daily = pick<Map<String, dynamic>>(jsonMap, 'daily') ?? {};

//     // ---- 현재값
//     final currTemp = (current['temperature_2m'] as num?)?.toDouble(); // 현재 기온
//     final currHumidity = (current['relative_humidity_2m'] as num?)
//         ?.toInt(); // 현재 습도
//     final currWind = (current['wind_speed_10m'] as num?)?.toDouble(); // 현재 풍속

//     // ---- 일일값
//     final dailyMaxList =
//         (daily['temperature_2m_max'] as List?)?.cast<num>() ?? const [];
//     final dailyMinList =
//         (daily['temperature_2m_min'] as List?)?.cast<num>() ?? const [];
//     final sunriseList = (daily['sunrise'] as List?)?.cast<String>() ?? const [];
//     final sunsetList = (daily['sunset'] as List?)?.cast<String>() ?? const [];
//     final uvMaxList = (daily['uv_index_max'] as List?)?.cast<num>() ?? const [];

//     // ★ 첫째 날 데이터만 사용
//     final high = dailyMaxList.isNotEmpty ? dailyMaxList.first.round() : null;
//     final low = dailyMinList.isNotEmpty ? dailyMinList.first.round() : null;
//     final sunrise = sunriseList.isNotEmpty
//         ? sunriseList.first.substring(11, 16)
//         : '-';
//     final sunset = sunsetList.isNotEmpty
//         ? sunsetList.first.substring(11, 16)
//         : '-';
//     final uv = uvMaxList.isNotEmpty ? uvMaxList.first.round() : null;

//     // ---- 시간별 값
//     final timeList = (hourly['time'] as List?)?.cast<String>() ?? const [];
//     final tempList =
//         (hourly['temperature_2m'] as List?)?.cast<num>() ?? const [];
//     final popList =
//         (hourly['precipitation_probability'] as List?)?.cast<num>() ?? const [];
//     final codeList = (hourly['weathercode'] as List?)?.cast<num>() ?? const [];

//     // ---- 현재 시각 기준 시작 인덱스 계산 (07:30 → 07:00 시작)
//     final now = DateTime.now();
//     int startIndex = 0;
//     for (int i = 0; i < timeList.length; i++) {
//       final t = DateTime.tryParse(timeList[i]);
//       if (t != null && t.hour == now.hour && t.minute == 0) {
//         startIndex = i;
//         break;
//       }
//       if (t != null && t.isBefore(now)) {
//         startIndex = i; // 정확히 매칭이 없으면 직전 시각으로
//       }
//     }

//     // ---- 24시간만 슬라이싱
//     final endIndex = (startIndex + 24 <= timeList.length)
//         ? startIndex + 24
//         : timeList.length;

//     // ---- 화면용 리스트 생성
//     final List<Map<String, dynamic>> rows = [];
//     for (int i = startIndex; i < endIndex; i++) {
//       final hhmm = timeList[i].length >= 16
//           ? timeList[i].substring(11, 16)
//           : timeList[i];
//       final code = i < codeList.length ? codeList[i].toInt() : 0;
//       rows.add({
//         'hour': hhmm, // 시각
//         'icon': _iconFromWeatherCode(code), // 날씨 아이콘
//         'temp': i < tempList.length ? tempList[i].round() : null, // 온도
//         'pop': i < popList.length ? popList[i].toInt() : null, // 강수확률
//       });
//     }

//     // ---- 상태 업데이트
//     _summary = {
//       'city': cityName, // ★ 영문 도시명 반영
//       'current': currTemp?.round(),
//       'high': high,
//       'low': low,
//       'feelsLike': currTemp?.round(), // 간단히 현재 기온 사용
//       'humidity': currHumidity,
//       'uv': uv,
//       'wind': currWind,
//       'sunrise': sunrise,
//       'sunset': sunset,
//     };
//     _hourly = rows;
//   }

//   // ----------------------------- weathercode → 아이콘 -----------------------------
//   IconData _iconFromWeatherCode(int code) {
//     // 참고: https://open-meteo.com/ (weathercode 표)
//     // 0: 맑음, 1~3: 대체로 맑음/부분적 구름, 45/48: 안개, 51~67: 이슬비/비,
//     // 71~77: 눈, 80~82: 소나기, 95/96/99: 뇌우
//     if (code == 0) return Icons.wb_sunny_outlined;
//     if (code == 1 || code == 2 || code == 3) return Icons.cloud_outlined;
//     if (code == 45 || code == 48) return Icons.blur_on; // 안개 대체 아이콘
//     if (code >= 51 && code <= 67) return Icons.grain; // 이슬비/비
//     if (code >= 71 && code <= 77) return Icons.ac_unit; // 눈
//     if (code >= 80 && code <= 82) return Icons.cloud_queue; // 소나기
//     if (code == 95 || code == 96 || code == 99) return Icons.thunderstorm; // 뇌우
//     return Icons.wb_cloudy_outlined;
//   }

//   // ----------------------------- UI -----------------------------
//   Widget _buildHeader(BuildContext context) {
//     return Container(
//       color: primary,
//       padding: const EdgeInsets.only(top: 52, left: 12, right: 12, bottom: 10),
//       child: Row(
//         children: const [
//           _BackButtonWhite(),
//           Spacer(),
//           Text(
//             'Weather',
//             style: TextStyle(
//               fontSize: 18,
//               fontFamily: 'Futura',
//               color: Colors.white,
//             ),
//           ),
//           Spacer(),
//           SizedBox(width: 24),
//         ],
//       ),
//     );
//   }

//   Widget _buildLocationAndHL() {
//     return Container(
//       color: primary,
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//       child: Column(
//         children: [
//           // ------------------ 위치명 ------------------
//           Row(
//             children: [
//               const Text(
//                 'Current location ',
//                 style: TextStyle(
//                   fontFamily: 'Futura',
//                   color: Colors.white,
//                   fontSize: 14,
//                 ),
//               ),
//               const Icon(Icons.location_on, size: 16, color: Colors.white),
//               const SizedBox(width: 6),
//               Text(
//                 _summary['city']?.toString() ?? '-',
//                 style: const TextStyle(
//                   fontFamily: 'Futura',
//                   color: Colors.white,
//                   fontSize: 14,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 12),

//           // ------------------ 최고 / 최저 / 체감 ------------------
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               // 최고
//               const Icon(Icons.thermostat, color: accentRed, size: 18),
//               Text(
//                 ' ${_summary['high'] ?? '-'}°C ',
//                 style: const TextStyle(
//                   color: accentRed,
//                   fontFamily: 'Futura',
//                   fontSize: 16,
//                 ),
//               ),
//               const Text(
//                 ' / ',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 16,
//                   fontFamily: 'Futura',
//                 ),
//               ),
//               // 최저
//               const Icon(Icons.ac_unit, color: accentBlue, size: 18),
//               Text(
//                 ' ${_summary['low'] ?? '-'}°C',
//                 style: const TextStyle(
//                   color: accentBlue,
//                   fontFamily: 'Futura',
//                   fontSize: 16,
//                 ),
//               ),

//               const SizedBox(width: 12),

//               // feels like
//               Text(
//                 'feels like: ${_summary['feelsLike'] ?? '-'}°C',
//                 style: const TextStyle(
//                   color: Colors.white,
//                   fontFamily: 'Futura',
//                   fontSize: 14,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//         ],
//       ),
//     );
//   }

//   // ----------------------------- ★ 열 단위 동기 스크롤 테이블 -----------------------------
//   Widget _buildHourlyTable() {
//     const double leftColW = 112; // 라벨 고정 폭
//     const double colW = 72; // 각 시간 열의 폭
//     const double gap = 12; // 열 간 간격
//     const double rowGap = 10; // 행 간 간격

//     List<Widget> _buildHourColumns() {
//       return List.generate(_hourly.length, (i) {
//         final h = _hourly[i];
//         return Padding(
//           padding: EdgeInsets.only(right: i == _hourly.length - 1 ? 0 : gap),
//           child: SizedBox(
//             width: colW,
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // 시각
//                 Text(
//                   (h['hour'] ?? '-') as String,
//                   style: const TextStyle(
//                     fontFamily: 'Futura',
//                     color: textSub,
//                     fontSize: 13,
//                     fontWeight: FontWeight.w600,
//                   ),
//                 ),
//                 SizedBox(height: rowGap),
//                 // 날씨 아이콘
//                 Icon(
//                   (h['icon'] as IconData?) ?? Icons.wb_cloudy_outlined,
//                   color: accentRed,
//                   size: 26,
//                 ),
//                 SizedBox(height: rowGap),
//                 // 온도
//                 Text(
//                   h['temp'] != null ? '${h['temp']}°C' : '-',
//                   style: const TextStyle(
//                     fontFamily: 'Futura',
//                     fontWeight: FontWeight.w600,
//                     color: textMain,
//                   ),
//                 ),
//                 SizedBox(height: rowGap),
//                 // 강수확률
//                 Text(
//                   h['pop'] != null ? '${h['pop']}%' : '-',
//                   style: const TextStyle(fontFamily: 'Futura', color: textMain),
//                 ),
//               ],
//             ),
//           ),
//         );
//       });
//     }

//     return Column(
//       children: [
//         Container(
//           decoration: BoxDecoration(
//             color: cardBgAlt,
//             borderRadius: BorderRadius.circular(12),
//           ),
//           padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // 좌측 라벨 열 (고정)
//               SizedBox(
//                 width: leftColW,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: const [
//                     Text(
//                       'Time',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontFamily: 'Futura',
//                         color: textSub,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                     SizedBox(height: 10),
//                     Text(
//                       'Weather',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(fontFamily: 'Futura', color: textSub),
//                     ),
//                     SizedBox(height: 10),
//                     Text(
//                       'Temperature',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(fontFamily: 'Futura', color: textSub),
//                     ),
//                     SizedBox(height: 10),
//                     Text(
//                       'Chance of\nprecipitation',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(fontFamily: 'Futura', color: textSub),
//                     ),
//                   ],
//                 ),
//               ),
//               // 우측: 시간별 열의 단일 가로 스크롤
//               Expanded(
//                 child: SingleChildScrollView(
//                   controller: _hScrollCtrl,
//                   scrollDirection: Axis.horizontal,
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: _buildHourColumns(),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTripleCards() {
//     return Row(
//       children: [
//         Expanded(
//           child: _MiniCard(
//             icon: Icons.water_drop_outlined,
//             title: 'humidity',
//             valueKey: 'humidity',
//             suffix: '%',
//           ),
//         ),
//         const SizedBox(width: 8),
//         Expanded(
//           child: _MiniCard(
//             icon: Icons.wb_sunny_outlined,
//             title: 'UV index',
//             valueKey: 'uv',
//             suffix: '',
//           ),
//         ),
//         const SizedBox(width: 8),
//         Expanded(
//           child: _MiniCard(
//             icon: Icons.air,
//             title: 'wind speed',
//             valueKey: 'wind',
//             suffix: ' m/s',
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildSunBar() {
//     return Container(
//       decoration: BoxDecoration(
//         color: cardBgAlt,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//       child: Row(
//         children: [
//           const Icon(Icons.wb_twighlight, color: accentRed),
//           const SizedBox(width: 8),
//           Text(
//             'sunrise ${_summary['sunrise']}',
//             style: const TextStyle(fontFamily: 'Futura', color: textMain),
//           ),
//           const Spacer(),
//           const Icon(Icons.nightlight_round, color: accentBlue),
//           const SizedBox(width: 8),
//           Text(
//             'sunset ${_summary['sunset']}',
//             style: const TextStyle(fontFamily: 'Futura', color: textMain),
//           ),
//         ],
//       ),
//     );
//   }

//   // ----------------------------- build -----------------------------
//   @override
//   Widget build(BuildContext context) {
//     final isError = _error != null;

//     return Scaffold(
//       backgroundColor: const Color(0xFFFBFBFB),
//       body: SafeArea(
//         child: Column(
//           children: [
//             _buildHeader(context),
//             _buildLocationAndHL(),
//             if (_loading) const LinearProgressIndicator(minHeight: 2),
//             if (isError)
//               Container(
//                 width: double.infinity,
//                 color: Colors.red.withOpacity(0.08),
//                 padding: const EdgeInsets.all(12),
//                 child: Text(
//                   'エラー: ${_error!}',
//                   style: const TextStyle(color: Colors.red),
//                 ),
//               ),
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 12,
//                 ),
//                 child: Column(
//                   children: [
//                     _buildHourlyTable(),
//                     const SizedBox(height: 12),
//                     _buildTripleCards(),
//                     const SizedBox(height: 12),
//                     _buildSunBar(),
//                     const SizedBox(height: 16),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ----------------------------- 보조 위젯 -----------------------------
// class _BackButtonWhite extends StatelessWidget {
//   const _BackButtonWhite();

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: () => Navigator.maybePop(context),
//       child: const Icon(Icons.arrow_back, color: Colors.white),
//     );
//   }
// }

// class _MiniCard extends StatelessWidget {
//   final IconData icon;
//   final String title;
//   final String valueKey;
//   final String suffix;

//   const _MiniCard({
//     required this.icon,
//     required this.title,
//     required this.valueKey,
//     required this.suffix,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final state = context.findAncestorStateOfType<_WeatherScreenState>();
//     final summary = state?._summary ?? const {};
//     final raw = summary[valueKey];
//     final value = raw == null ? '-' : raw.toString();

//     return Container(
//       height: 74,
//       decoration: BoxDecoration(
//         color: _WeatherScreenState.cardBgAlt,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
//       child: Row(
//         children: [
//           Icon(icon, color: _WeatherScreenState.textSub),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontFamily: 'Futura',
//                     fontSize: 13,
//                     color: _WeatherScreenState.textSub,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   '$value$suffix',
//                   style: const TextStyle(
//                     fontFamily: 'Futura',
//                     fontWeight: FontWeight.w600,
//                     color: _WeatherScreenState.textMain,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
