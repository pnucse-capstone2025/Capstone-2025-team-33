// modify_clothes.dart
// ★ 주석은 한국어로 작성했습니다.
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // ★ 갤러리/카메라 이미지 선택
import 'package:file_picker/file_picker.dart'; // ★ 파일 선택
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // ★ JWT 토큰 저장/읽기

class ModifyClothesScreen extends StatefulWidget {
  const ModifyClothesScreen({Key? key}) : super(key: key);

  @override
  State<ModifyClothesScreen> createState() => _ModifyClothesScreenState();
}

class _ModifyClothesScreenState extends State<ModifyClothesScreen> {
  int? _clothesId; // ★ 수정할 아이템 id

  // ---------------- 날짜/숫자 상태 ----------------
  DateTime? lastUsedDate;
  DateTime? purchaseDate;
  final TextEditingController timesUsedController = TextEditingController();

  // ---------------- 이미지 상태 ----------------
  File? _imageFile; // ★ 새로 선택한 이미지 파일
  final ImagePicker _picker = ImagePicker();
  String? _initialImageUrl; // ★ 서버에 저장된 기존 이미지 URL

  // ---------------- 선택 항목 ----------------
  String? gender;
  String? masterCategory;
  String? subCategory;
  String? articleType;
  String? baseColor;
  final Set<String> seasons = {};
  String? usage;

  // ---------------- 상수 목록 ----------------
  static const List<String> genders = [
    'Men',
    'Women',
    'Boys',
    'Girls',
    'Unisex',
  ];
  static const List<String> masterCategories = [
    'Accessories',
    'Apparel',
    'Footwear',
    'Free Items',
    'Home',
    'Personal Care',
    'Sporting Goods',
  ];
  static const List<String> subCategories = [
    'Accessories',
    'Apparel Set',
    'Bags',
    'Bath and Body',
    'Beauty Accessories',
    'Belts',
    'Bottomwear',
    'Cufflinks',
    'Dress',
    'Eyes',
    'Eyewear',
    'Flip Flops',
    'Fragrance',
    'Free Gifts',
    'Gloves',
    'Hair',
    'Headwear',
    'Home Furnishing',
    'Innerwear',
    'Jewellery',
    'Lips',
    'Loungewear and Nightwear',
    'Makeup',
    'Mufflers',
    'Nails',
    'Perfumes',
    'Sandal',
    'Saree',
    'Scarves',
    'Shoe Accessories',
    'Shoes',
    'Skin',
    'Skin Care',
    'Socks',
    'Sports Accessories',
    'Sports Equipment',
    'Stoles',
    'Ties',
    'Topwear',
    'Umbrellas',
    'Vouchers',
    'Wallets',
    'Watches',
    'Water Bottle',
    'Wristbands',
  ];
  static const List<String> articleTypes = [
    'Accessory Gift Set',
    'Baby Dolls',
    'Backpacks',
    'Bangle',
    'Basketballs',
    'Bath Robe',
    'Beauty Accessory',
    'Belts',
    'Blazers',
    'Body Lotion',
    'Body Wash and Scrub',
    'Booties',
    'Boxers',
    'Bra',
    'Bracelet',
    'Briefs',
    'Camisoles',
    'Capris',
    'Caps',
    'Casual Shoes',
    'Churidar',
    'Clothing Set',
    'Clutches',
    'Compact',
    'Concealer',
    'Cufflinks',
    'Cushion Covers',
    'Deodorant',
    'Dresses',
    'Duffel Bag',
    'Dupatta',
    'Earrings',
    'Eye Cream',
    'Eyeshadow',
    'Face Moisturisers',
    'Face Scrub and Exfoliator',
    'Face Serum and Gel',
    'Face Wash and Cleanser',
    'Flats',
    'Flip Flops',
    'Footballs',
    'Formal Shoes',
    'Foundation and Primer',
    'Fragrance Gift Set',
    'Free Gifts',
    'Gloves',
    'Hair Accessory',
    'Hair Colour',
    'Handbags',
    'Hat',
    'Headband',
    'Heels',
    'Highlighter and Blush',
    'Innerwear Vests',
    'Ipad',
    'Jackets',
    'Jeans',
    'Jeggings',
    'Jewellery Set',
    'Jumpsuit',
    'Kajal and Eyeliner',
    'Key chain',
    'Kurta Sets',
    'Kurtas',
    'Kurtis',
    'Laptop Bag',
    'Leggings',
    'Lehenga Choli',
    'Lip Care',
    'Lip Gloss',
    'Lip Liner',
    'Lip Plumper',
    'Lipstick',
    'Lounge Pants',
    'Lounge Shorts',
    'Lounge Tshirts',
    'Makeup Remover',
    'Mascara',
    'Mask and Peel',
    'Mens Grooming Kit',
    'Messenger Bag',
    'Mobile Pouch',
    'Mufflers',
    'Nail Essentials',
    'Nail Polish',
    'Necklace and Chains',
    'Nehru Jackets',
    'Night suits',
    'Nightdress',
    'Patiala',
    'Pendant',
    'Perfume and Body Mist',
    'Rain Jacket',
    'Rain Trousers',
    'Ring',
    'Robe',
    'Rompers',
    'Rucksacks',
    'Salwar',
    'Salwar and Dupatta',
    'Sandals',
    'Sarees',
    'Scarves',
    'Shapewear',
    'Shirts',
    'Shoe Accessories',
    'Shoe Laces',
    'Shorts',
    'Shrug',
    'Skirts',
    'Socks',
    'Sports Sandals',
    'Sports Shoes',
    'Stockings',
    'Stoles',
    'Suits',
    'Sunglasses',
    'Sunscreen',
    'Suspenders',
    'Sweaters',
    'Sweatshirts',
    'Swimwear',
    'Tablet Sleeve',
    'Ties',
    'Ties and Cufflinks',
    'Tights',
    'Toner',
    'Tops',
    'Track Pants',
    'Tracksuits',
    'Travel Accessory',
    'Trolley Bag',
    'Trousers',
    'Trunk',
    'Tshirts',
    'Tunics',
    'Umbrellas',
    'Waist Pouch',
    'Waistcoat',
    'Wallets',
    'Watches',
    'Water Bottle',
    'Wristbands',
  ];
  static const List<String> baseColors = [
    'Beige',
    'Black',
    'Blue',
    'Bronze',
    'Brown',
    'Burgundy',
    'Charcoal',
    'Coffee Brown',
    'Copper',
    'Cream',
    'Fluorescent Green',
    'Gold',
    'Green',
    'Grey',
    'Grey Melange',
    'Khaki',
    'Lavender',
    'Lime Green',
    'Magenta',
    'Maroon',
    'Mauve',
    'Metallic',
    'Multi',
    'Mushroom Brown',
    'Mustard',
    'Navy Blue',
    'Nude',
    'Off White',
    'Olive',
    'Orange',
    'Peach',
    'Pink',
    'Purple',
    'Red',
    'Rose',
    'Rust',
    'Sea Green',
    'Silver',
    'Skin',
    'Steel',
    'Tan',
    'Taupe',
    'Teal',
    'Turquoise Blue',
    'White',
    'Yellow',
  ];
  static const List<String> seasonOptions = [
    'Spring',
    'Summer',
    'Fall',
    'Winter',
  ];
  static const List<String> usages = [
    'Casual',
    'Ethnic',
    'Formal',
    'Home',
    'Party',
    'Smart Casual',
    'Sports',
    'Travel',
  ];

  // ---------------- 유효성 체크 ----------------
  bool get _isValidRequired =>
      (gender?.isNotEmpty ?? false) &&
      (masterCategory?.isNotEmpty ?? false) &&
      (subCategory?.isNotEmpty ?? false) &&
      (baseColor?.isNotEmpty ?? false) &&
      seasons.isNotEmpty &&
      (usage?.isNotEmpty ?? false);

  // ---------------- 초기값 로딩 ----------------
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<dynamic, dynamic>?;

      if (args != null && args['id'] != null) {
        _clothesId = args['id'] as int;
        _fetchClothingDetail(_clothesId!); // ★ 항상 서버에서 최신 데이터 가져오기
      }
    });
  }

  @override
  void dispose() {
    timesUsedController.dispose();
    super.dispose();
  }

  Future<void> _fetchClothingDetail(int id) async {
    try {
      final url = Uri.parse("http://127.0.0.1:8000/api/clothes/$id/");
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: "access_token");

      final resp = await http.get(
        url,
        headers: {"Authorization": "Bearer $token"},
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);

        setState(() {
          _clothesId = data['id'];
          _initialImageUrl = data['image'];
          gender = data['gender'];
          masterCategory = data['masterCategory'];
          subCategory = data['subCategory'];
          articleType = data['articleType'];
          baseColor = data['baseColor'];
          usage = data['usage'];
          seasons
            ..clear()
            ..addAll((data['season'] as String).split(','));
          timesUsedController.text = data['timesUsed']?.toString() ?? '';
          lastUsedDate = data['lastUsed'] != null
              ? DateTime.tryParse(data['lastUsed'])
              : null;
          purchaseDate = data['purchaseDate'] != null
              ? DateTime.tryParse(data['purchaseDate'])
              : null;
        });
      } else {
        debugPrint("Failed to fetch detail: ${resp.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching detail: $e");
    }
  }

  // ---------------- 날짜 선택 ----------------
  Future<void> _selectDate(BuildContext context, bool isLastUsed) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isLastUsed ? lastUsedDate : purchaseDate) ?? DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isLastUsed)
          lastUsedDate = picked;
        else
          purchaseDate = picked;
      });
    }
  }

  // ---------------- 갤러리에서 이미지 선택 ----------------
  Future<void> _pickImage(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('select from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? picked = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (picked != null) {
                    setState(() {
                      _imageFile = File(picked.path);
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('select from Files'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'heic'],
                  );
                  if (result != null && result.files.single.path != null) {
                    setState(() {
                      _imageFile = File(result.files.single.path!);
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ★ 저장(PATCH)
  Future<void> _saveClothing() async {
    if (!_isValidRequired || _clothesId == null) return;

    try {
      final url = Uri.parse("http://127.0.0.1:8000/api/clothes/$_clothesId/");
      final request = http.MultipartRequest("PATCH", url);

      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: "access_token");
      if (token != null) {
        request.headers["Authorization"] = "Bearer $token";
      }

      request.fields["gender"] = gender ?? "";
      request.fields["masterCategory"] = masterCategory ?? "";
      request.fields["subCategory"] = subCategory ?? "";
      request.fields["articleType"] = articleType ?? "";
      request.fields["baseColor"] = baseColor ?? "";
      request.fields["season"] = seasons.join(",");
      request.fields["usage"] = usage ?? "";
      request.fields["timesUsed"] = timesUsedController.text;

      if (lastUsedDate != null)
        request.fields["lastUsed"] = lastUsedDate!.toIso8601String();
      if (purchaseDate != null)
        request.fields["purchaseDate"] = purchaseDate!.toIso8601String();

      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath("image", _imageFile!.path),
        );
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("failed to renew (${response.statusCode})")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("ネットワークエラー: $e")));
      }
    }
  }

  // ★ 삭제(DELETE)
  Future<void> _confirmDelete() async {
    if (_clothesId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('Do you want to delete this item?'),
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
    if (ok == true) {
      try {
        final url = Uri.parse("http://127.0.0.1:8000/api/clothes/$_clothesId/");
        final storage = const FlutterSecureStorage();
        final token = await storage.read(key: "access_token");
        final resp = await http.delete(
          url,
          headers: {"Authorization": "Bearer $token"},
        );

        if (resp.statusCode == 204 && mounted) {
          Navigator.pop(context, true); // ✅ 성공 → 목록 리프레시
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("failed to delete (${resp.statusCode})")),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("네트워크 오류: $e")));
        }
      }
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFBFB69B),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text(
          'Item Detail',
          style: TextStyle(fontFamily: 'Futura', color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ---------- 이미지 프리뷰 ----------
              AspectRatio(
                aspectRatio: 1.6,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE3E3E3)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : (_initialImageUrl != null
                            ? Image.network(
                                _initialImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.image_not_supported),
                              )
                            : const Icon(
                                Icons.checkroom,
                                size: 36,
                                color: Colors.grey,
                              )),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _pickImage(context),
                icon: const Icon(Icons.camera_alt),
                label: Text(
                  (_imageFile == null && _initialImageUrl == null)
                      ? 'Add Photo'
                      : 'Change Photo',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBF634E),
                  foregroundColor: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              // ---------- 입력 필드 ----------
              _DropdownRow(
                label: 'Gender',
                value: gender,
                items: genders,
                onChanged: (v) => setState(() => gender = v),
              ),
              _DropdownRow(
                label: 'Master Category',
                value: masterCategory,
                items: masterCategories,
                onChanged: (v) => setState(() => masterCategory = v),
              ),
              _SearchableRow(
                label: 'Sub Category',
                value: subCategory,
                options: subCategories,
                onChanged: (v) => setState(() => subCategory = v),
              ),
              _SearchableRow(
                label: 'Article Type',
                value: articleType,
                options: articleTypes,
                onChanged: (v) => setState(() => articleType = v),
              ),
              _DropdownRow(
                label: 'Base Color',
                value: baseColor,
                items: baseColors,
                onChanged: (v) => setState(() => baseColor = v),
              ),

              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Season"),
              ),
              Wrap(
                spacing: 8,
                children: seasonOptions.map((s) {
                  final selected = seasons.contains(s);
                  return FilterChip(
                    label: Text(s),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v)
                        seasons.add(s);
                      else
                        seasons.remove(s);
                    }),
                    selectedColor: const Color(0xFFBF634E).withOpacity(0.15),
                    checkmarkColor: const Color(0xFFBF634E),
                  );
                }).toList(),
              ),

              _DropdownRow(
                label: 'Usage',
                value: usage,
                items: usages,
                onChanged: (v) => setState(() => usage = v),
              ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isValidRequired ? _saveClothing : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBF634E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text("Save"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Dropdown 공통 위젯 ----------------
class _DropdownRow extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 1, color: Colors.black12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontFamily: 'Futura'),
            ),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                value: value != null && items.contains(value) ? value : null,
                items: items
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: onChanged,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------- Autocomplete 공통 위젯 ----------------
class _SearchableRow extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _SearchableRow({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value ?? '');
    return Column(
      children: [
        const Divider(height: 1, color: Colors.black12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontFamily: 'Futura'),
            ),
            SizedBox(
              width: 220,
              child: Autocomplete<String>(
                initialValue: TextEditingValue(text: value ?? ''),
                optionsBuilder: (textValue) {
                  final q = textValue.text.trim().toLowerCase();
                  if (q.isEmpty) return options;
                  return options.where((o) => o.toLowerCase().contains(q));
                },
                onSelected: onChanged,
                fieldViewBuilder: (context, textCtrl, focusNode, _) {
                  textCtrl.text = controller.text;
                  return TextField(
                    controller: textCtrl,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
