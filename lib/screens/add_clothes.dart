// add_clothes.dart
// ★ 주석은 한국어로 작성했습니다.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart'; // ★ 카메라/갤러리 픽커
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // ★ JWT 토큰 저장/읽기

class AddClothesScreen extends StatefulWidget {
  const AddClothesScreen({Key? key}) : super(key: key);

  @override
  State<AddClothesScreen> createState() => _AddClothesScreenState();
}

class _AddClothesScreenState extends State<AddClothesScreen> {
  // ---------------- 날짜/숫자 상태 ----------------
  DateTime? lastUsedDate;
  DateTime? purchaseDate;
  final TextEditingController timesUsedController = TextEditingController();

  // ---------------- 이미지 상태 ----------------
  // ★ 중앙 버튼으로 촬영/선택한 이미지 파일
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // ---------------- 선택 항목(필수 포함) ----------------
  String? gender; // ★ 필수
  String? masterCategory; // ★ 필수
  String? subCategory; // ★ 필수 (검색 가능)
  String? articleType; // ★ 선택 자유 (검색 가능)
  String? baseColor; // ★ 필수
  final Set<String> seasons = {}; // ★ 필수(복수 선택 가능)
  String? usage; // ★ 필수

  // ---------------- 선택지 상수 ----------------
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

  // ---------------- 유효성 체크(저장 버튼 활성 제어) ----------------
  bool get _isValidRequired =>
      (gender != null && gender!.isNotEmpty) &&
      (masterCategory != null && masterCategory!.isNotEmpty) &&
      (subCategory != null && subCategory!.isNotEmpty) &&
      (baseColor != null && baseColor!.isNotEmpty) &&
      seasons.isNotEmpty &&
      (usage != null && usage!.isNotEmpty);

  // ---------------- 변경 여부(닫기 확인용) ----------------
  bool get _isDirty {
    return _imageFile != null ||
        lastUsedDate != null ||
        purchaseDate != null ||
        (timesUsedController.text.trim().isNotEmpty) ||
        gender != null ||
        masterCategory != null ||
        subCategory != null ||
        articleType != null ||
        baseColor != null ||
        seasons.isNotEmpty ||
        usage != null;
  }

  // ---------------- 날짜 선택 ----------------
  Future<void> _selectDate(BuildContext context, bool isLastUsed) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2030),
      helpText: isLastUsed ? 'Select last used date' : 'Select purchase date',
    );
    if (picked != null) {
      setState(() {
        if (isLastUsed) {
          lastUsedDate = picked;
        } else {
          purchaseDate = picked;
        }
      });
    }
  }

  // ---------------- 이미지 등록 (카메라 or 갤러리 선택) ----------------
  Future<void> _pickImage(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Select from Gallery'),
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
                title: const Text('Select from Files'),
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

  Future<void> _saveClothing() async {
    if (!_isValidRequired) return;

    try {
      final url = Uri.parse("http://127.0.0.1:8000/api/clothes/");
      final request = http.MultipartRequest("POST", url);

      // ★ JWT 토큰 읽기
      final storage = const FlutterSecureStorage();
      final token = await storage.read(key: "access_token");
      if (token != null) {
        request.headers["Authorization"] = "Bearer $token"; // ★ 인증 헤더 추가
      }

      // ---- 텍스트 필드 ----
      request.fields["gender"] = gender ?? "";
      request.fields["masterCategory"] = masterCategory ?? "";
      request.fields["subCategory"] = subCategory ?? "";
      request.fields["articleType"] = articleType ?? "";
      request.fields["baseColor"] = baseColor ?? "";
      request.fields["season"] = seasons.join(",");
      request.fields["usage"] = usage ?? "";

      // ---- 이미지 파일 ----
      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath("image", _imageFile!.path),
        );
      }

      final response = await request.send();

      if (response.statusCode == 201) {
        debugPrint("Clothes added successfully!");
        if (mounted) Navigator.pop(context, true);
      } else {
        debugPrint("Failed to add clothes: ${response.statusCode}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("保存失敗 (${response.statusCode})")),
          );
        }
      }
    } catch (e) {
      debugPrint("Error saving clothes: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("ネットワークエラー: $e")));
      }
    }
  }

  // ---------------- 닫기 확인 ----------------
  Future<void> _tryClose() async {
    if (!_isDirty) {
      if (mounted) Navigator.pop(context, false);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('Do you want to close without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // No → 닫지 않음
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Yes → 닫기
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context, false);
    }
  }

  @override
  void dispose() {
    timesUsedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ★ 전체를 세로 스크롤 가능하게: SingleChildScrollView 사용
    return WillPopScope(
      onWillPop: () async {
        if (!_isDirty) return true;
        await _tryClose();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFBFBFB),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ---------------- 상단 바 ----------------
                Container(
                  color: const Color(0xFFBFB69B),
                  padding: const EdgeInsets.only(
                    top: 16,
                    left: 16,
                    right: 16,
                    bottom: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      // ★ 우상단 카메라 버튼 제거
                      //  - 닫기(×)만 유지
                      //  - 가운데 제목
                      _AppBarCloseAndTitle(),
                    ],
                  ),
                ),

                // ---------------- 이미지 + 사진 버튼 + 날짜/횟수 카드 ----------------
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE3E3E3)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      // ★ 이미지 미리보기
                      AspectRatio(
                        aspectRatio: 1.6,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE3E3E3)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _imageFile == null
                              ? const Center(
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 36,
                                    color: Colors.grey,
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    _imageFile!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ★ 중앙(가운데) 사진 등록/변경 버튼 → LAST USED 위에 위치
                      Center(
                        child: SizedBox(
                          width: 200,
                          height: 42,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _pickImage(context), // ★ 버튼 탭 시 촬영/등록
                            icon: const Icon(Icons.camera_alt),
                            label: Text(
                              _imageFile == null ? 'Add Photo' : 'Change Photo',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBF634E),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ★ LAST USED 이하
                      _buildDateRow(
                        'LAST USED',
                        lastUsedDate,
                        () => _selectDate(context, true),
                      ),
                      _buildTextFieldRow('TIMES USED', timesUsedController),
                      _buildDateRow(
                        'PURCHASE DATE',
                        purchaseDate,
                        () => _selectDate(context, false),
                      ),
                    ],
                  ),
                ),

                // ---------------- 기본 정보 타이틀 ----------------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  color: const Color(0xFFBF9B9B),
                  child: const Text(
                    'Basic Information (required)',
                    style: TextStyle(
                      color: Color(0xFFF9F2ED),
                      fontFamily: 'Futura',
                      fontSize: 16,
                    ),
                  ),
                ),

                // ---------------- 입력/선택 필드 ----------------
                ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 0,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
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
                      hintText: 'Search sub category…',
                      onChanged: (v) => setState(() => subCategory = v),
                    ),
                    _SearchableRow(
                      label: 'Article Type',
                      value: articleType,
                      options: articleTypes,
                      hintText: 'Search article type…',
                      onChanged: (v) => setState(() => articleType = v),
                    ),
                    _DropdownRow(
                      label: 'Base Color',
                      value: baseColor,
                      items: baseColors,
                      onChanged: (v) => setState(() => baseColor = v),
                    ),
                    const SizedBox(height: 8),
                    const _Label('Season'),
                    Wrap(
                      spacing: 8,
                      children: seasonOptions.map((s) {
                        final selected = seasons.contains(s);
                        return FilterChip(
                          label: Text(s),
                          selected: selected,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                seasons.add(s);
                              } else {
                                seasons.remove(s);
                              }
                            });
                          },
                          selectedColor: const Color(
                            0xFFBF634E,
                          ).withOpacity(0.15),
                          checkmarkColor: const Color(0xFFBF634E),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    _DropdownRow(
                      label: 'Usage',
                      value: usage,
                      items: usages,
                      onChanged: (v) => setState(() => usage = v),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),

                // ---------------- 저장 버튼 ----------------
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBF634E),
                      disabledBackgroundColor: const Color(
                        0xFFBF634E,
                      ).withOpacity(0.4),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: _isValidRequired ? _saveClothing : null,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- 날짜 행 ----------------
  Widget _buildDateRow(String label, DateTime? date, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Label(label),
        TextButton(
          onPressed: onTap,
          child: Text(
            date != null ? DateFormat('yyyy/MM/dd').format(date) : '—/—/—',
            style: const TextStyle(color: Colors.black),
          ),
        ),
      ],
    );
  }

  // ---------------- 숫자 입력 행 ----------------
  Widget _buildTextFieldRow(String label, TextEditingController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _Label(label),
        SizedBox(
          width: 80,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }
}

// ---------------- AppBar 닫기+제목 (카메라 버튼 제거) ----------------
class _AppBarCloseAndTitle extends StatelessWidget {
  const _AppBarCloseAndTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () async {
            // ★ 상위 state의 _tryClose 호출을 직접 접근할 수 없으므로
            //   Navigator.pop으로 단순 종료를 원하면 여기서 처리 가능.
            //   현재는 디자인 상 AppBar에서의 확인 다이얼로그는 생략.
            Navigator.maybePop(context);
          },
          child: const Icon(Icons.close, color: Colors.white),
        ),
        const Text(
          'Add Item',
          style: TextStyle(
            color: Color(0xFFF9F2ED),
            fontFamily: 'Futura',
            fontSize: 16,
          ),
        ),
        const SizedBox(width: 24), // 우측 여백(아이콘 자리 균형용)
      ],
    );
  }
}

// ---------------- 라벨 공통 위젯 ----------------
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontFamily: 'Futura'),
    );
  }
}

// ---------------- 드롭다운 행(일반 선택) ----------------
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
        SizedBox(
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Label(label),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: value,
                  items: items
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Futura'),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: onChanged,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 10,
                    ),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- 검색 가능한 선택 행(Autocomplete) ----------------
class _SearchableRow extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> options;
  final String hintText;
  final ValueChanged<String> onChanged;

  const _SearchableRow({
    required this.label,
    required this.value,
    required this.options,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: value ?? '');
    return Column(
      children: [
        const Divider(height: 1, color: Colors.black12),
        SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Label(label),
              SizedBox(
                width: 220,
                child: Autocomplete<String>(
                  initialValue: TextEditingValue(text: value ?? ''),
                  optionsBuilder: (TextEditingValue textValue) {
                    final q = textValue.text.trim().toLowerCase();
                    if (q.isEmpty) return options;
                    return options.where((o) => o.toLowerCase().contains(q));
                  },
                  onSelected: (sel) => onChanged(sel),
                  fieldViewBuilder:
                      (context, textCtrl, focusNode, onFieldSubmitted) {
                        // ★ 외부 value와 동기화
                        textCtrl.text = controller.text;
                        textCtrl.selection = TextSelection.fromPosition(
                          TextPosition(offset: textCtrl.text.length),
                        );
                        return TextField(
                          controller: textCtrl,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: hintText,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 10,
                            ),
                          ),
                          onSubmitted: (v) {
                            if (options.contains(v)) onChanged(v);
                          },
                        );
                      },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
