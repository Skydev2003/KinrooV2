import 'dart:io';
import 'dart:typed_data'; // ✅ 1. เพิ่ม import นี้เพื่อใช้ Uint8List
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_screen.dart';

class ScanFoodScreen extends StatefulWidget {
  const ScanFoodScreen({super.key});

  @override
  _ScanFoodScreenState createState() => _ScanFoodScreenState();
}

class _ScanFoodScreenState extends State<ScanFoodScreen>
    with TickerProviderStateMixin {
  XFile? _image;
  Interpreter? _interpreter;
  final TextEditingController _foodController = TextEditingController();
  double calories = 0, protein = 0, fat = 0, carbs = 0;
  double confidence = 0.0;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Custom colors
  final Color primaryBlue = const Color.fromARGB(255, 47, 130, 174);
  final Color primaryBrown = const Color.fromARGB(255, 70, 51, 43);

  @override
  void initState() {
    super.initState();
    _lockOrientation();
    _loadModel();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _unlockOrientation();
    _animationController.dispose();
    super.dispose();
  }

  void _lockOrientation() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _unlockOrientation() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _loadModel() async {
    setState(() => _isLoading = true);
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/kinrooV5.tflite',
      );
      print("✅ โมเดลโหลดสำเร็จ!");
    } catch (e) {
      print("❌ โหลดโมเดลล้มเหลว: $e");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image == null) return;

    setState(() => _image = image);
    await _analyzeFood(image);
  }

  Future<void> _analyzeFood(XFile image) async {
    if (_interpreter == null) {
      print("⚠️ โมเดลยังไม่ถูกโหลด!");
      return;
    }

    try {
      var input = _processImage(image);
      // สร้าง Output buffer ตามขนาดที่โมเดลต้องการ (1 row, 50 classes)
      var output = List.generate(1, (_) => List.filled(50, 0.0));

      _interpreter!.run(input, output);

      setState(() {
        final result = _mapFoodLabelWithConfidence(output[0]);
        String predictedFood = result['food'];
        confidence = result['confidence'];

        _foodController.text = predictedFood;
        _getNutritionData(predictedFood);
      });
    } catch (e) {
      print("❌ Error analyzing food: $e");
    }
  }

  void _getNutritionData(String food) {
    final nutritionData = {
      "กระเพราหมูสับ": [300, 20, 15, 40],
      "กระเพราเนื้อเปื่อย": [320, 22, 18, 38],
      "กระเพราไก่": [280, 18, 12, 45],
      "ก๋วยเตี๋ยว": [250, 10, 5, 50],
      "ขนมจีนน้ำยา": [400, 25, 10, 55],
      "ข้าวขาหมู": [550, 30, 20, 60],
      "ข้าวซอยไก่": [500, 28, 15, 55],
      "ข้าวต้มกุ้ง": [320, 25, 8, 50],
      "ข้าวต้มปลา": [300, 22, 7, 48],
      "ข้าวต้มหมูสับ": [340, 26, 10, 52],
      "ข้าวผัดกุ้ง": [450, 30, 12, 58],
      "ข้าวผัดไข่": [400, 20, 10, 60],
      "ข้าวมันไก่": [600, 35, 25, 65],
      "ข้าวหมูทอดกระเทียม": [550, 30, 20, 58],
      "ข้าวหมูแดง": [500, 28, 18, 55],
      "ข้าวเหนียวหมูปิ้ง": [450, 32, 12, 62],
      "ข้าวไข่เจียว": [420, 28, 15, 55],
      "คอหมูย่าง": [500, 35, 30, 40],
      "คะน้าหมูกรอบ": [480, 25, 22, 50],
      "ชาบู": [350, 30, 10, 45],
      "ซูชิ": [280, 18, 5, 55],
      "ต้มยำกุ้ง": [360, 25, 8, 50],
      "ต้มเนื้อ": [400, 30, 12, 52],
      "ต้มไก่": [350, 28, 8, 45],
      "น้ำปั่นผลไม้": [180, 0, 0, 45],
      "น้ำอัดลม": [150, 0, 0, 40],
      "บะหมี่กึ่งสำเร็จรูป": [450, 10, 18, 60],
      "ปลาทอด": [400, 35, 20, 40],
      "ปลาหมึกผัดไข่เค็ม": [480, 30, 15, 55],
      "ผัดกะเพราหมูกรอบ": [500, 28, 22, 50],
      "ผัดซีอิ๊วหมู": [450, 25, 12, 60],
      "ผัดผักรวมมิตร": [300, 15, 8, 55],
      "ผัดไทย": [550, 30, 10, 65],
      "ยำทะเล": [350, 40, 12, 35],
      "ลาบหมู": [420, 30, 15, 50],
      "ลูกชิ้นหมู": [380, 25, 10, 45],
      "สปาเกตตีผัดขี้เมา": [550, 30, 15, 60],
      "สลัดผัก": [250, 10, 5, 40],
      "สุกี้น้ำ": [400, 30, 8, 50],
      "ส้มตำ": [200, 5, 2, 45],
      "หมูกระทะ": [600, 40, 30, 50],
      "หอยทอด": [550, 30, 20, 55],
      "แกงจืด": [250, 15, 5, 40],
      "แกงหน่อไม้": [350, 18, 10, 50],
      "แกงเขียวหวาน": [450, 30, 15, 55],
      "ไก่ทอด": [600, 35, 25, 50],
      "ไก่ย่าง": [450, 30, 10, 55],
      "ไข่พะโล้": [350, 20, 10, 40],
      "ไม่มีอาหาร": [0, 0, 0, 0],
      "ไส้กรอกอีสาน": [500, 28, 22, 40],
    };

    if (nutritionData.containsKey(food)) {
      final data = nutritionData[food]!;
      calories = data[0].toDouble();
      protein = data[1].toDouble();
      fat = data[2].toDouble();
      carbs = data[3].toDouble();
    } else {
      calories = protein = fat = carbs = 0;
    }
  }

  Future<void> _saveToFirebase(String userId) async {
    try {
      final docRef = FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .collection("food_history")
          .doc();

      await docRef.set({
        "food": _foodController.text,
        "calories": calories,
        "protein": protein,
        "fat": fat,
        "carbs": carbs,
        "timestamp": FieldValue.serverTimestamp(),
      });

      print("✅ บันทึกไปยัง Firebase สำเร็จ! (ID: ${docRef.id})");
      await fetchUserNutritionData();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      print("❌ เกิดข้อผิดพลาดขณะบันทึก Firebase: $e");
    }
  }

  Widget _buildGradientButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    Color? backgroundColor,
    AlignmentGeometry? alignment,
  }) {
    // ✅ 3. ใช้ withOpacity แทน withValues เพื่อความเสถียร
    return Container(
      width: double.infinity,
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: alignment,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: backgroundColor != null
              ? [backgroundColor, backgroundColor.withOpacity(0.8)]
              : [primaryBlue, primaryBlue.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryBrown,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: primaryBrown),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "กำลังโหลดโมเดล AI...",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : _image == null
                    ? _buildInitialView()
                    : _buildResultView(),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryBlue, primaryBrown],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Icon(Icons.camera_alt_rounded, size: 60, color: Colors.white),
                const SizedBox(height: 15),
                const Text(
                  "สแกนอาหาร",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "ถ่ายรูปหรือเลือกรูปอาหารเพื่อวิเคราะห์",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildGradientButton(
            text: "เปิดกล้อง",
            icon: Icons.camera_alt,
            onPressed: () => _pickImage(ImageSource.camera),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 1.0,
              child: _buildGradientButton(
                text: "เลือกจากแกลลอรี่",
                icon: Icons.photo_library,
                onPressed: () => _pickImage(ImageSource.gallery),
                backgroundColor: primaryBlue,
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("เมนูที่รองรับ"),
                        content: const SingleChildScrollView(
                          child: Text(
                            "แอพพลิเคชั่นตอนนี้รองรับเมนูอาหาร 50 เมนู...", // ตัดข้อความสั้นๆ เพื่อความกระชับในตัวอย่าง
                            style: TextStyle(fontSize: 14, height: 1.5),
                          ),
                        ),
                        actions: [
                          TextButton(
                            child: const Text("ปิด"),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    );
                  },
                  child: CircleAvatar(
                    backgroundColor: primaryBlue.withOpacity(0.1),
                    radius: 24,
                    child: Icon(Icons.info_outline, color: primaryBlue, size: 28),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "วิธีใช้งาน",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "1. ถ่ายรูปหรือเลือกรูปอาหาร\n2. รอระบบวิเคราะห์\n3. ตรวจสอบค่าความถูกต้อง\n4. แก้ไขชื่ออาหารหากจำเป็น\n5. บันทึกข้อมูลโภชนาการ",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: IconButton(
                onPressed: () => setState(() => _image = null),
                icon: Icon(Icons.arrow_back_ios, color: primaryBlue),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.file(File(_image!.path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      confidence >= 70 ? Icons.check_circle : Icons.warning,
                      color: confidence >= 70 ? Colors.green : Colors.orange,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "ความถูกต้อง",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: primaryBrown,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: confidence / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          confidence >= 70
                              ? Colors.green
                              : confidence >= 50
                              ? Colors.orange
                              : Colors.red,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "${confidence.toInt()}%",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: confidence >= 70
                            ? Colors.green
                            : confidence >= 50
                            ? Colors.orange
                            : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ชื่ออาหาร",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryBrown,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _foodController,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "แก้ไขชื่ออาหาร",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: primaryBlue.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryBlue, width: 2),
                    ),
                    prefixIcon: Icon(Icons.restaurant, color: primaryBlue),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (value) => setState(() {
                    _getNutritionData(value);
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Text(
            "ข้อมูลโภชนาการ",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryBrown,
            ),
          ),
          const SizedBox(height: 15),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.2,
            children: [
              _buildNutritionCard(
                label: "แคลอรี่",
                value: "${calories.toInt()} kcal",
                icon: Icons.local_fire_department,
                color: Colors.orange,
              ),
              _buildNutritionCard(
                label: "โปรตีน",
                value: "${protein.toInt()} g",
                icon: Icons.fitness_center,
                color: Colors.red,
              ),
              _buildNutritionCard(
                label: "ไขมัน",
                value: "${fat.toInt()} g",
                icon: Icons.opacity,
                color: Colors.yellow[700]!,
              ),
              _buildNutritionCard(
                label: "คาร์โบไฮเดรต",
                value: "${carbs.toInt()} g",
                icon: Icons.grain,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 30),
          if (confidence < 50) ...[
            _buildGradientButton(
              text: "ถ่ายรูปใหม่",
              icon: Icons.camera_alt,
              onPressed: () => _pickImage(ImageSource.camera),
              backgroundColor: Colors.orange,
            ),
            const SizedBox(height: 10),
          ],
          _buildGradientButton(
            text: "บันทึกข้อมูล",
            icon: Icons.save,
            onPressed: () async {
              String userId = getCurrentUserId();
              await _saveToFirebase(userId);
            },
          ),
        ],
      ),
    );
  }

  Future<void> fetchUserNutritionData() async {}
}

// ✅ 2. อัปเดตฟังก์ชันนี้ให้รองรับ image package v4+
// เลิกใช้ getPixelSafe และ bitwise operation แบบเก่า
List<List<List<List<double>>>> _processImage(XFile image) {
  final bytes = File(image.path).readAsBytesSync();
  final decodedImage = img.decodeImage(Uint8List.fromList(bytes));

  if (decodedImage == null) {
    throw Exception("ไม่สามารถอ่านรูปภาพได้");
  }

  // Resize รูปภาพ
  final resizedImage = img.copyResize(decodedImage, width: 224, height: 224);

  // แปลงค่า Pixel เป็น input ที่ Normalized แล้ว (0.0 - 1.0)
  // รองรับ Image package v4 ที่ pixel.r, pixel.g, pixel.b เข้าถึงได้โดยตรง
  final input = List.generate(
    1,
    (_) => List.generate(
      224,
      (y) => List.generate(
        224,
        (x) {
          final pixel = resizedImage.getPixel(x, y);
          return [
            pixel.r / 255.0, // Red
            pixel.g / 255.0, // Green
            pixel.b / 255.0, // Blue
          ];
        },
      ),
    ),
  );

  return input;
}

Map<String, dynamic> _mapFoodLabelWithConfidence(List<double> predictions) {
  final foodLabels = [
    "กระเพราหมูสับ", "กระเพราเนื้อเปื่อย", "กระเพราไก่", "ก๋วยเตี๋ยว", "ขนมจีนน้ำยา",
    "ข้าวขาหมู", "ข้าวซอยไก่", "ข้าวต้มกุ้ง", "ข้าวต้มปลา", "ข้าวต้มหมูสับ",
    "ข้าวผัดกุ้ง", "ข้าวผัดไข่", "ข้าวมันไก่", "ข้าวหมูทอดกระเทียม", "ข้าวหมูแดง",
    "ข้าวเหนียวหมูปิ้ง", "ข้าวไข่เจียว", "คอหมูย่าง", "คะน้าหมูกรอบ", "ชาบู",
    "ซูชิ", "ต้มยำกุ้ง", "ต้มเนื้อ", "ต้มไก่", "น้ำปั่นผลไม้",
    "น้ำอัดลม", "บะหมี่กึ่งสำเร็จรูป", "ปลาทอด", "ปลาหมึกผัดไข่เค็ม", "ผัดกะเพราหมูกรอบ",
    "ผัดซีอิ๊วหมู", "ผัดผักรวมมิตร", "ผัดไทย", "ยำทะเล", "ลาบหมู",
    "ลูกชิ้นหมู", "สปาเกตตีผัดขี้เมา", "สลัดผัก", "สุกี้น้ำ", "ส้มตำ",
    "หมูกระทะ", "หอยทอด", "แกงจืด", "แกงหน่อไม้", "แกงเขียวหวาน",
    "ไก่ทอด", "ไก่ย่าง", "ไข่พะโล้", "ไม่มีอาหาร", "ไส้กรอกอีสาน",
  ];

  double maxValue = predictions.reduce((a, b) => a > b ? a : b);
  int predictedIndex = predictions.indexOf(maxValue);
  double confidenceValue = maxValue * 100;

  String foodName = (predictedIndex >= 0 && predictedIndex < foodLabels.length)
      ? foodLabels[predictedIndex]
      : "อาหารไม่รู้จัก";

  return {'food': foodName, 'confidence': confidenceValue};
}

String getCurrentUserId() {
  final user = FirebaseAuth.instance.currentUser;
  return user?.uid ?? "unknown_user";
}