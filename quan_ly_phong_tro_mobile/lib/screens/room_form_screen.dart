import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/room.dart';

class RoomFormScreen extends StatefulWidget {
  const RoomFormScreen({super.key, required this.api, this.room});

  final ApiClient api;
  final Room? room;

  @override
  State<RoomFormScreen> createState() => _RoomFormScreenState();
}

class _RoomFormScreenState extends State<RoomFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _electric;
  late final TextEditingController _water;
  late final TextEditingController _wifi;
  late final TextEditingController _trash;
  late final TextEditingController _tenant;
  late bool _isEmpty;
  late bool _hasWifi;
  bool _saving = false;

  bool get _editing => widget.room != null;

  @override
  void initState() {
    super.initState();
    final room = widget.room;
    _name = TextEditingController(text: room?.roomName ?? '');
    _price = TextEditingController(text: room?.price.toStringAsFixed(0) ?? '');
    _electric = TextEditingController(
      text: room?.electricPrice.toStringAsFixed(0) ?? '3500',
    );
    _water = TextEditingController(
      text: room?.waterPrice.toStringAsFixed(0) ?? '20000',
    );
    _wifi = TextEditingController(
      text: room?.wifiPrice.toStringAsFixed(0) ?? '50000',
    );
    _trash = TextEditingController(
      text: room?.trashPrice.toStringAsFixed(0) ?? '10000',
    );
    _tenant = TextEditingController(text: room?.tenantUsername ?? '');
    _isEmpty = room?.status ?? true;
    _hasWifi = room?.hasWifi ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _electric.dispose();
    _water.dispose();
    _wifi.dispose();
    _trash.dispose();
    _tenant.dispose();
    super.dispose();
  }

  double? _number(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'roomName': _name.text.trim(),
      'price': _number(_price.text),
      'status': _isEmpty,
      'tenantUsername': _tenant.text.trim().isEmpty ? null : _tenant.text.trim(),
      'electricPrice': _number(_electric.text),
      'waterPrice': _number(_water.text),
      'wifiPrice': _number(_wifi.text),
      'hasWifi': _hasWifi,
      'trashPrice': _number(_trash.text),
    };

    try {
      if (_editing) {
        await widget.api.put('/rooms/${widget.room!.id}', body: body);
      } else {
        await widget.api.post('/rooms', body: body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _moneyField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      validator: (value) {
        if (value == null || _number(value) == null) return 'Nhập số hợp lệ';
        if (_number(value)! < 0) return 'Không được nhỏ hơn 0';
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Sửa phòng' : 'Thêm phòng')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên phòng'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Vui lòng nhập tên phòng'
                  : null,
            ),
            const SizedBox(height: 12),
            _moneyField('Giá phòng', _price),
            const SizedBox(height: 12),
            _moneyField('Giá điện / số', _electric),
            const SizedBox(height: 12),
            _moneyField('Giá nước / số', _water),
            const SizedBox(height: 12),
            _moneyField('Phí WiFi', _wifi),
            const SizedBox(height: 12),
            _moneyField('Phí rác', _trash),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tenant,
              decoration: const InputDecoration(
                labelText: 'Username người thuê (nếu có)',
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Phòng đang trống'),
              value: _isEmpty,
              onChanged: (value) => setState(() => _isEmpty = value),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Có WiFi'),
              value: _hasWifi,
              onChanged: (value) => setState(() => _hasWifi = value),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
