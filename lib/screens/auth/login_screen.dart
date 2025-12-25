import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../user_flow/home_user_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    String inputEmail = _emailController.text.trim();
    String inputPassword = _passwordController.text.trim();

    // 1. Kiểm tra nhập liệu cơ bản
    if (inputEmail.isEmpty || inputPassword.isEmpty) {
      _showError('Vui lòng nhập đầy đủ Email và Mật khẩu!');
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // 2. Tìm trong Database xem có nhân viên này không
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: inputEmail)
          .where('role', isEqualTo: 'technician')
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // --- TÌM THẤY TÀI KHOẢN ---
        var userDoc = snapshot.docs.first;
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

        // --- BƯỚC KIỂM TRA MẬT KHẨU MỚI ---
        // Lấy pass từ DB (nếu không có trường password thì mặc định là '123456')
        String dbPassword = data['password'];

        // So sánh
        if (inputPassword != dbPassword) {
          _showError('Sai mật khẩu! Vui lòng kiểm tra lại.');
          setState(() { _isLoading = false; });
          return; // Dừng lại, không cho đăng nhập
        }
        // ------------------------------------

        // Kiểm tra trạng thái hoạt động
        bool isActive = data['isActive'] ?? true;

        if (isActive) {
          // Tài khoản OK -> Cho vào
          _goToHome();
        } else {
          // Tài khoản đã bị STAFF khóa
          _showError('Tài khoản này đã bị VÔ HIỆU HÓA. Vui lòng liên hệ quản lý!');
        }
      } else {
        // --- KHÔNG TÌM THẤY TRONG DB ---
        // Vẫn giữ backdoor 'user' để test nhanh nếu cần (hoặc bạn có thể xóa đoạn này đi nếu muốn bảo mật hoàn toàn)
        if (inputEmail == 'user') {
          _goToHome();
        } else {
          _showError('Email không tồn tại trong hệ thống!');
        }
      }
    } catch (e) {
      _showError('Lỗi kết nối: $e');
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _goToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeUserScreen(
          userEmail: _emailController.text.trim(), // <--- TRUYỀN EMAIL VÀO ĐÂY
        ),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng nhập thành công!')));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.engineering, size: 80, color: Colors.blue),
                const SizedBox(height: 20),
                const Text(
                  'KỸ THUẬT VIÊN',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'VD: nhanvienA@gmail.com',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu',
                    hintText: 'Nhập mật khẩu của bạn', // Sửa hintText
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('ĐĂNG NHẬP', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}