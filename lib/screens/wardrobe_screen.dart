// wardrobe_screen.dart
// ★ 주석은 한국어로 작성했습니다.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fashion_frontend/screens/add_clothes.dart';
import 'package:fashion_frontend/screens/modify_clothes.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();

/// ★ 카테고리 상수 (탭 순서 고정)
const List<String> _categories = <String>[
  'ALL',
  'TOPS',
  'BOTTOMS',
  'OUTER',
  'SHOES',
  'ACCESSORIES',
  'BAGS',
  'OTHER',
];

// ---------------- 카테고리 매핑 함수 ----------------
/// Django subCategory → 앱 탭으로 변환
String mapSubCategoryToTab(String sub) {
  sub = sub.toUpperCase();

  if ([
    "TOPWEAR",
    "DRESS",
    "INNERWEAR",
    "LOUNGEWEAR AND NIGHTWEAR",
  ].contains(sub)) {
    return "TOPS";
  } else if (["BOTTOMWEAR"].contains(sub)) {
    return "BOTTOMS";
  } else if ([
    "OUTERWEAR",
    "APPAREL SET",
    "JACKETS",
    "SWEATERS",
    "COATS",
  ].any((s) => sub.contains(s))) {
    return "OUTER";
  } else if ([
    "SHOES",
    "SANDAL",
    "FLIP FLOPS",
    "SHOE ACCESSORIES",
  ].any((s) => sub.contains(s))) {
    return "SHOES";
  } else if ([
    "ACCESSORIES",
    "JEWELLERY",
    "WATCHES",
    "BELTS",
    "MUFFLERS",
    "SCARVES",
    "GLOVES",
    "HEADWEAR",
    "SOCKS",
    "TIES",
    "CUFFLINKS",
    "WRISTBANDS",
  ].any((s) => sub.contains(s))) {
    return "ACCESSORIES";
  } else if (["BAGS", "WALLETS"].any((s) => sub.contains(s))) {
    return "BAGS";
  } else {
    return "OTHER";
  }
}

/// ★ 색상(앱 전체 톤에 맞춤)
const Color _primary = Color(0xFFBFB69B);
const Color _secondary = Color(0xFFBF634E);
const Color _border = Color(0xFFE3E3E3);
const Color _bg = Color(0xFFFBFBFB);

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({Key? key}) : super(key: key);

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  List<dynamic> _items = []; // ★ 서버에서 받아올 옷 리스트

  @override
  void initState() {
    super.initState();
    _fetchClothes();
  }

  // ---------------- Django API에서 옷 목록 불러오기 ----------------
  final storage = FlutterSecureStorage();

  Future<void> _fetchClothes() async {
    try {
      final token = await storage.read(key: "access_token"); // ★ 저장된 JWT 토큰 읽기
      if (token == null) {
        debugPrint("No token found");
        return;
      }

      final url = Uri.parse("http://127.0.0.1:8000/api/clothes/");
      final response = await http.get(
        url,
        headers: {
          "Authorization": "Bearer $token", // ★ JWT 토큰 헤더에 포함
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _items = jsonDecode(response.body);
        });
      } else {
        debugPrint("Failed to load clothes: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching clothes: $e");
    }
  }

  // ---------------- 필터링 함수 ----------------
  List<dynamic> _filterByCategory(String cat) {
    if (cat == 'ALL') return _items;

    return _items.where((e) {
      final sub = (e['subCategory'] ?? '').toString();
      final mapped = mapSubCategoryToTab(sub);
      return mapped == cat;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _primary,
          title: const Text(
            'My Closet',
            style: TextStyle(
              fontFamily: 'Futura',
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () async {
                // ---------------- 추가 화면으로 이동 ----------------
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddClothesScreen()),
                );
                if (result == true) {
                  _fetchClothes();
                }
              },
              tooltip: 'Add',
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.8),
            labelStyle: const TextStyle(fontFamily: 'Futura', fontSize: 13),
            indicatorColor: Colors.white,
            indicatorWeight: 2.4,
            tabs: _categories.map((c) => Tab(text: c)).toList(),
          ),
        ),
        body: TabBarView(
          children: _categories.map((cat) {
            final data = _filterByCategory(cat);
            return _GridSection(
              items: data,
              // ---------------- 아이템 탭 시 상세 수정 ----------------
              onTapItem: (item) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ModifyClothesScreen(),
                    settings: RouteSettings(arguments: item),
                  ),
                ).then((refresh) {
                  if (refresh == true) {
                    _fetchClothes(); // 최신 목록 다시 불러오기
                  }
                });
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// ---------------- 그리드 섹션 위젯 ----------------
class _GridSection extends StatelessWidget {
  final List<dynamic> items;
  final void Function(dynamic item) onTapItem;

  const _GridSection({required this.items, required this.onTapItem});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No items yet',
          style: TextStyle(fontFamily: 'Futura', color: Color(0xFF707070)),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _ClosetCard(
          // ★ DB에서 불러온 이미지 URL 사용 (없으면 placeholder)
          imagePath: item['image'] ?? '',
          title: item['articleType'] ?? 'No name',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ModifyClothesScreen(),
                settings: RouteSettings(
                  arguments: {
                    'id': item['id'],
                    'image': item['image'], // ★ 서버 이미지 URL
                    'gender': item['gender'],
                    'masterCategory': item['masterCategory'],
                    'subCategory': item['subCategory'],
                    'articleType': item['articleType'],
                    'baseColor': item['baseColor'],
                    'season': item['season'], // ★ "Spring,Summer" 형태 문자열
                    'usage': item['usage'],
                    'timesUsed': item['timesUsed'], // 있으면
                    'lastUsed': item['lastUsed'], // 있으면 ISO8601
                    'purchaseDate': item['purchaseDate'], // 있으면 ISO8601
                  },
                ),
              ),
            ).then((changed) {
              if (changed == true) {
                // ★ 수정 후 목록 갱신
                final state = context
                    .findAncestorStateOfType<_WardrobeScreenState>();
                state?._fetchClothes();
              }
            });
          },
        );
      },
    );
  }
}

/// ---------------- 단일 카드 ----------------
class _ClosetCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final VoidCallback onTap;

  const _ClosetCard({
    required this.imagePath,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseUrl = "http://127.0.0.1:8000";
    final fullUrl = imagePath.startsWith("http")
        ? imagePath
        : "$baseUrl$imagePath";
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),

                child: imagePath.isNotEmpty
                    ? Image.network(
                        fullUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFFEFEFEF),
                          child: Center(child: Icon(Icons.image_not_supported)),
                        ),
                      )
                    : const ColoredBox(
                        color: Color(0xFFEFEFEF),
                        child: Center(child: Icon(Icons.checkroom)),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Futura',
                  fontSize: 12,
                  color: Color(0xFF0D0D0D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
