import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../../models/incident_model.dart';

class IncidentDetailScreen extends StatefulWidget {
  final IncidentModel incident;
  const IncidentDetailScreen({super.key, required this.incident});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  bool _isUpdating = false;

  // Hàm xử lý khi KTV sửa xong
  Future<void> _markAsCompleted() async {
    // Theo quy trình: Chụp ảnh sau khi sửa (Ở đây mình demo bước xác nhận trước)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận hoàn thành"),
        content: const Text("Bạn đã sửa xong sự cố này chưa?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Chưa")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Đã xong"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpdating = true);

    try {
      // Cập nhật trạng thái lên Firebase
      await FirebaseFirestore.instance
          .collection('incidents')
          .doc(widget.incident.id)
          .update({
        'status': 'Resolved', // Chuyển sang Đã xong
        'resolvedTime': DateTime.now().millisecondsSinceEpoch, // Lưu thời gian xong
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã cập nhật trạng thái: HOÀN THÀNH!")));
        Navigator.pop(context); // Quay về danh sách
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
    } finally {
      setState(() => _isUpdating = false);
    }
  }

  // Widget hiển thị trạng thái màu sắc
  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    switch (status) {
      case 'Resolved': color = Colors.green; label = "Đã hoàn thành"; break;
      case 'Processing': color = Colors.blue; label = "Đang xử lý"; break;
      default: color = Colors.orange; label = "Chờ tiếp nhận";
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chi tiết sự cố")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Ảnh hiện trường
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: widget.incident.imageUrl.isNotEmpty
                  ? Image.memory(base64Decode(widget.incident.imageUrl), fit: BoxFit.cover, width: double.infinity, height: 250)
                  : Container(height: 250, color: Colors.grey[300], child: const Center(child: Icon(Icons.image_not_supported, size: 50))),
            ),
            const SizedBox(height: 20),

            // 2. Tiêu đề và Trạng thái
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(widget.incident.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                _buildStatusBadge(widget.incident.status),
              ],
            ),
            const SizedBox(height: 10),

            // 3. Thông tin chi tiết
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _rowInfo(Icons.category, "Loại", widget.incident.category),
                    const Divider(),
                    _rowInfo(Icons.location_on, "Vị trí", widget.incident.location),
                    const Divider(),
                    _rowInfo(Icons.description, "Mô tả", widget.incident.description),
                    const Divider(),
                    _rowInfo(Icons.access_time, "Thời gian báo", widget.incident.timestamp.toString().substring(0, 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // 4. Nút Hoàn thành (Chỉ hiện khi trạng thái là Processing)
            if (widget.incident.status == 'Processing')
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isUpdating ? null : _markAsCompleted,
                  icon: const Icon(Icons.check_circle),
                  label: _isUpdating
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("BÁO CÁO HOÀN THÀNH CÔNG VIỆC"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
              ),

            // Nếu đã xong rồi thì hiện thông báo
            if (widget.incident.status == 'Resolved')
              const Center(child: Text("Sự cố này đã được khắc phục xong.", style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic))),
          ],
        ),
      ),
    );
  }

  Widget _rowInfo(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 10),
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}