import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/auth/login_screen.dart';
// import 'screens/user_flow/home_user_screen.dart'; // Giữ lại nếu cần import

void main() async {
  // 1. Dòng bắt buộc để chạy các lệnh async
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 2. Điền cứng thông tin kết nối (Cấu hình riêng cho USER APP)
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyCOJU4k1mRshEPHjjP3IvhG84BEEf-QGfo", // Giống Staff

        // --- CHÚ Ý: App ID này khác với Staff nhé (đuôi 4c9) ---
        appId: "1:110963805676:android:107309326b22de13a784c9",

        messagingSenderId: "110963805676", // Giống Staff
        projectId: "maintenanceapp-3e232", // Giống Staff
      ),
    );
    print("User App: Kết nối Firebase thành công!");
  } catch (e) {
    print("User App: Lỗi khởi tạo Firebase: $e");
  }

  // 3. Chạy App
  runApp(const MaintenanceApp());
}

class MaintenanceApp extends StatelessWidget {
  const MaintenanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Maintenance User',
      theme: ThemeData(
        primarySwatch: Colors.blue, // User dùng màu Xanh dương
        useMaterial3: true,
      ),
      // Màn hình đầu tiên là Login
      home: const LoginScreen(),
    );
  }
}