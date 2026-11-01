import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/app_user.dart';
import '../models/room.dart';

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, required this.api, this.user});

  final ApiClient api;
  final AppUser? user;

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username;
  final _password = TextEditingController();
  late final TextEditingController _fullName;
  String _role = 'Tenant';
  int? _roomId;
  List<Room> _rooms = const [];
  bool _loadingRooms = true;
  bool _saving = false;

  bool get _editing => widget.user != null;

  @override
  void initState() {
    super.initState();
    _username = TextEditingController(text: widget.user?.username ?? '');
    _fullName = TextEditingController(text: widget.user?.fullName ?? '');
    if (widget.user != null) {
      _role = _canonicalRole(widget.user!.role);
      _roomId = widget.user!.roomId;
    }
    _loadRooms();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  String _canonicalRole(String value) {
    switch (value.toLowerCase()) {
      case 'owner':
        return 'Owner';
      case 'manager':
        return 'Manager';
      default:
        return 'Tenant';
    }
  }

  Future<void> _loadRooms() async {
    try {
      final data = await widget.api.get('/rooms') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _rooms = data
            .map((e) => Room.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
    } finally {
      if (mounted) setState(() => _loadingRooms = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final body = {
      'username': _username.text.trim(),
      'password': _password.text,
      'fullName': _fullName.text.trim().isEmpty ? null : _fullName.text.trim(),
      'role': _role,
      'roomId': _role == 'Tenant' ? _roomId : null,
    };

    try {
      if (_editing) {
        await widget.api.put('/users/${widget.user!.id}', body: body);
      } else {
        await widget.api.post('/users', body: body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Sửa tài khoản' : 'Tạo tài khoản')),
      body: _loadingRooms
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(labelText: 'Tên đăng nhập'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Vui lòng nhập tên đăng nhập'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: _editing
                          ? 'Mật khẩu mới (để trống nếu không đổi)'
                          : 'Mật khẩu',
                    ),
                    validator: (value) {
                      if (!_editing && (value == null || value.isEmpty)) {
                        return 'Vui lòng nhập mật khẩu';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullName,
                    decoration: const InputDecoration(labelText: 'Họ và tên'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: const InputDecoration(labelText: 'Vai trò'),
                    items: const [
                      DropdownMenuItem(value: 'Owner', child: Text('Chủ nhà')),
                      DropdownMenuItem(value: 'Manager', child: Text('Quản lý')),
                      DropdownMenuItem(value: 'Tenant', child: Text('Người thuê')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _role = value ?? 'Tenant';
                        if (_role != 'Tenant') _roomId = null;
                      });
                    },
                  ),
                  if (_role == 'Tenant') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _roomId ?? 0,
                      decoration: const InputDecoration(labelText: 'Phòng'),
                      items: [
                        const DropdownMenuItem<int>(
                          value: 0,
                          child: Text('Chưa gán phòng'),
                        ),
                        ..._rooms.map(
                          (room) => DropdownMenuItem<int>(
                            value: room.id,
                            child: Text(room.roomName),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _roomId = value == 0 ? null : value),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_saving ? 'Đang lưu...' : 'Lưu tài khoản'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
