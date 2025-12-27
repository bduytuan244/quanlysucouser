import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../../models/incident_model.dart';

class IncidentDetailScreen extends StatefulWidget {
  final IncidentModel incident;
  final bool isReadOnly;

  const IncidentDetailScreen({
    super.key,
    required this.incident,
    this.isReadOnly = false,
  });

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  bool _isUpdating = false;

  void _showFullImage(BuildContext context, String base64String) {
    if (base64String.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: Image.memory(base64Decode(base64String), fit: BoxFit.contain),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleCheckIn() async {
    setState(() => _isUpdating = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Bạn cần cấp quyền vị trí để check-in");
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Quyền vị trí bị từ chối vĩnh viễn. Hãy mở cài đặt.");
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      await FirebaseFirestore.instance
          .collection('incidents')
          .doc(widget.incident.id)
          .update({
        'status': 'Processing',
        'checkInTime': DateTime.now().millisecondsSinceEpoch,
        'checkInLocation': {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Đã Check-in thành công! Bắt đầu công việc.")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi Check-in: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showMaterialRequestDialog() {
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _qtyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Đề xuất vật tư'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên vật tư (VD: Dây điện)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _qtyController,
                decoration: const InputDecoration(labelText: 'Số lượng'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                if (_nameController.text.isNotEmpty) {
                  Navigator.pop(ctx);
                  await _saveMaterialRequest(_nameController.text, int.tryParse(_qtyController.text) ?? 1);
                }
              },
              child: const Text('Gửi yêu cầu'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveMaterialRequest(String name, int qty) async {
    try {
      await FirebaseFirestore.instance
          .collection('incidents')
          .doc(widget.incident.id)
          .collection('materials')
          .add({
        'name': name,
        'quantity': qty,
        'requestTime': DateTime.now().millisecondsSinceEpoch,
        'status': 'Pending',
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã gửi yêu cầu vật tư!")));
      }
    } catch (e) {
      print("Lỗi gửi vật tư: $e");
    }
  }

  Widget _buildRequestedMaterials() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          "📦 VẬT TƯ ĐÃ YÊU CẦU:",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('incidents')
              .doc(widget.incident.id)
              .collection('materials')
              .orderBy('requestTime', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text("Chưa có yêu cầu vật tư nào.", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var data = doc.data() as Map<String, dynamic>;
                String status = data['status'] ?? 'Pending';
                bool isApproved = status == 'Approved';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isApproved ? Colors.green[50] : Colors.orange[50],
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text("${data['quantity']}", style: TextStyle(color: isApproved ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      isApproved ? "✅ ĐÃ DUYỆT (Xuống kho lấy)" : "⏳ Đang chờ quản lý duyệt...",
                      style: TextStyle(
                          color: isApproved ? Colors.green[700] : Colors.orange[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 12
                      ),
                    ),
                    trailing: isApproved
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.hourglass_empty, color: Colors.orange),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 10),
        const Divider(thickness: 1),
      ],
    );
  }

  Future<void> _markAsCompleted() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận hoàn thành"),
        content: const Text("Bạn đã sửa xong sự cố này chưa?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Chưa")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text("Đã xong"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('incidents')
          .doc(widget.incident.id)
          .update({
        'status': 'Resolved',
        'resolvedTime': DateTime.now().millisecondsSinceEpoch,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã cập nhật trạng thái: HOÀN THÀNH!")));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

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
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    String timeString = "N/A";
    try {
      DateTime date = widget.incident.timestamp;

      timeString = "${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      timeString = "Không xác định";
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Chi tiết sự cố")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                if (widget.incident.imageUrl.isNotEmpty) {
                  _showFullImage(context, widget.incident.imageUrl);
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.incident.imageUrl.isNotEmpty
                    ? Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.memory(
                        base64Decode(widget.incident.imageUrl),
                        fit: BoxFit.cover, width: double.infinity, height: 250
                    ),
                    Positioned(
                      right: 10, bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: const Icon(Icons.zoom_in, color: Colors.white),
                      ),
                    )
                  ],
                )
                    : Container(height: 250, color: Colors.grey[300], child: const Center(child: Icon(Icons.image_not_supported, size: 50))),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(widget.incident.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                _buildStatusBadge(widget.incident.status),
              ],
            ),
            const SizedBox(height: 10),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _rowInfo(Icons.category, "Loại sự cố", widget.incident.category),
                    const Divider(),
                    _rowInfo(Icons.location_on, "Vị trí", widget.incident.location),
                    const Divider(),
                    _rowInfo(Icons.description, "Mô tả", widget.incident.description),
                    const Divider(),
                    _rowInfo(Icons.access_time, "Thời gian báo", timeString),
                    if (widget.incident.status != 'Pending') ...[
                      const Divider(),
                      _rowInfo(Icons.timer, "Đã check-in", "Đã ghi nhận vị trí"),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (widget.incident.status == 'Processing' || widget.incident.status == 'Resolved')
              _buildRequestedMaterials(),

            if (!widget.isReadOnly) ...[
              if (widget.incident.status == 'Pending')
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isUpdating ? null : _handleCheckIn,
                    icon: const Icon(Icons.location_on),
                    label: _isUpdating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("CHECK-IN VỊ TRÍ & BẮT ĐẦU LÀM"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                  ),
                ),

              if (widget.incident.status == 'Processing') ...[
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _showMaterialRequestDialog,
                    icon: const Icon(Icons.build),
                    label: const Text("ĐỀ XUẤT VẬT TƯ"),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.blue[800], side: BorderSide(color: Colors.blue[800]!)),
                  ),
                ),
                const SizedBox(height: 15),
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
              ],
            ],

            if (widget.isReadOnly && widget.incident.status == 'Pending')
              const Center(child: Text("Đang chờ nhân viên kỹ thuật tiếp nhận...", style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic))),

            if (widget.incident.status == 'Resolved')
              const Center(child: Padding(
                padding: EdgeInsets.only(top: 20.0),
                child: Text("Sự cố này đã được khắc phục xong.", style: TextStyle(color: Colors.green, fontStyle: FontStyle.italic, fontWeight: FontWeight.bold)),
              )),
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
          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}