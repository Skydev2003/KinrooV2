import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'input_birthday_screen.dart';
import 'home_screen.dart';

class GoogleRegisterScreen extends StatefulWidget {
  const GoogleRegisterScreen({super.key});

  @override
  State<GoogleRegisterScreen> createState() => _GoogleRegisterScreenState();
}

class _GoogleRegisterScreenState extends State<GoogleRegisterScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  static const String _iosClientId =
      '620249493204-es7gbhhmckimqhcqka8uta67du5pm3qg.apps.googleusercontent.com';

  // ใช้ clientId สำหรับ iOS เพื่อรองรับ Google Sign-In บน iPhone/iPad
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    clientId:
        defaultTargetPlatform == TargetPlatform.iOS ? _iosClientId : null,
  );

  // ฟังก์ชันสำหรับเปลี่ยนบัญชี Google

  Future<void> _createAccountWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      // ✅ ล็อกเอาท์จาก Google ก่อนเพื่อให้เลือกบัญชีใหม่ได้
      await _googleSignIn.signOut();

      // Begin interactive sign in process
      final GoogleSignInAccount? gUser = await _googleSignIn.signIn();

      if (gUser == null) {
        // User cancelled the sign-in
        setState(() => _isLoading = false);
        return;
      }

      // Obtain auth details from request
      final GoogleSignInAuthentication gAuth = await gUser.authentication;

      // Create a new credential for user
      final credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      // Sign in with Firebase (this creates the account if it doesn't exist)
      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      User? user = userCredential.user;

      if (user == null) throw Exception("สร้างบัญชีด้วย Google ไม่สำเร็จ");

      // Check if user document exists in Firestore
      DocumentSnapshot userDoc = await _firestore
          .collection("users")
          .doc(user.uid)
          .get();

      if (!mounted) return;

      // แสดงข้อความสำเร็จ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 เข้าสู่ระบบด้วย Google สำเร็จ!',
              style: TextStyle(fontSize: 16),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // รอ 0.5 วินาทีแล้วไปหน้าถัดไป
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          // Navigate to appropriate screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => userDoc.exists
                  ? const HomeScreen()
                  : const InputBirthdayScreen(),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Google Sign-Up Error: $e");
      }

      setState(() => _isLoading = false);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("สร้างบัญชีด้วย Google ไม่สำเร็จ: ${e.toString()}"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "สร้างบัญชีด้วย Google",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                "เข้าใช้งาน Kinroo ด้วยบัญชี Google ของคุณ\nง่าย รวดเร็ว และปลอดภัย",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 60),

              // Google Sign Up Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                  minimumSize: const Size(double.infinity, 55),
                  elevation: 2,
                ),
                onPressed: _isLoading ? null : _createAccountWithGoogle,
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Image.asset(
                        'assets/icon/google_logo.png',
                        height: 24,
                        width: 24,
                      ),
                label: Text(
                  _isLoading ? "กำลังสร้างบัญชี..." : "สร้างบัญชีด้วย Google",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                "การสร้างบัญชีแสดงว่าคุณยอมรับ\nข้อกำหนดการใช้งานและนโยบายความเป็นส่วนตัว",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
