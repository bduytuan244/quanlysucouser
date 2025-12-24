import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  // Để đơn giản cho demo, ta truyền thẳng email người đang đăng nhập vào đây
  final String userEmail;

  const ProfileScreen({super.key, required this.userEmail});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _docId; // Lưu ID tài liệu để update

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // 1. Tải thông tin người dùng lên form
  Future<void> _loadUserData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: widget.userEmail)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      setState(() {
        _docId = snapshot.docs.first.id;
        _nameController.text = data['name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
      });
    }
  }

  // 2. Lưu thay đổi thông tin cơ bản (Tên, SĐT)
  Future<void> _updateProfile() async {
    if (_docId == null) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(_docId).update({
        'name': _nameController.text,
        'phone': _phoneController.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cập nhật hồ sơ thành công!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 3. --- HÀM MỚI: Hiển thị hộp thoại Đổi Mật Khẩu ---
  void _showChangePasswordDialog() {
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Đổi mật khẩu"),
        content: TextField(
          controller: passController,
          obscureText: true, // Ẩn ký tự
          decoration: const InputDecoration(
            labelText: "Mật khẩu mới",
            hintText: "Nhập ít nhất 6 ký tự",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Hủy")
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate độ dài
              if (passController.text.trim().length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Mật khẩu phải có ít nhất 6 ký tự!"))
                );
                return;
              }

              // Cập nhật lên Firebase
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_docId)
                    .update({
                  'password': passController.text.trim(),
                });

                if (mounted) {
                  Navigator.pop(ctx); // Đóng hộp thoại
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Đổi mật khẩu thành công!"))
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
              }
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Hồ sơ cá nhân")),
      // Thêm SingleChildScrollView để tránh lỗi bàn phím che khuất
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          height: MediaQuery.of(context).size.height - 100, // Chiều cao tạm để Spacer hoạt động tốt trong ScrollView
          child: Column(
            children: [
              const CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
              const SizedBox(height: 20),

              // Email (Không cho sửa - Read only)
              TextField(
                readOnly: true,
                decoration: InputDecoration(
                    labelText: "Email (Không thể thay đổi)",
                    hintText: widget.userEmail,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[200]
                ),
              ),
              const SizedBox(height: 16),

              // Tên (Cho sửa)
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Họ và tên", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              // SĐT (Cho sửa)
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Số điện thoại", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 30),

              // Nút Lưu thay đổi thông tin
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("LƯU THÔNG TIN", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 16),

              // --- NÚT MỚI: ĐỔI MẬT KHẨU ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _showChangePasswordDialog,
                  icon: const Icon(Icons.key),
                  label: const Text("ĐỔI MẬT KHẨU"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),

              const Spacer(),

              // Nút Đăng xuất
              TextButton.icon(
                onPressed: () {
                  // Quay về màn Login
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                          (route) => false
                  );
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text("Đăng xuất", style: TextStyle(color: Colors.red, fontSize: 16)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}