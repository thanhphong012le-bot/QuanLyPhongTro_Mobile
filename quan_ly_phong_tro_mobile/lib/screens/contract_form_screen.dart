import 'package:flutter/material.dart';

import '../core/api_client.dart';

class ContractFormScreen extends StatefulWidget {
  const ContractFormScreen({
    super.key,
    required this.api,
    this.embedded = false,
  });

  final ApiClient api;
  final bool embedded;

  @override
  State<ContractFormScreen> createState() => _ContractFormScreenState();
}

class _ContractFormScreenState extends State<ContractFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _cccd = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  DateTime _startDate = DateTime.now();
  int _term = 1;
  bool _saving = false;

  @override
  void dispose() {
    _fullName.dispose();
    _cccd.dispose();
    _address.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      initialDate: _startDate,
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.post('/contracts', body: {
        'fullName': _fullName.text.trim(),
        'cccd': _cccd.text.trim(),
        'address': _address.text.trim(),
        'phoneNumber': _phone.text.trim(),
        'startDate': _startDate.toIso8601String(),
        'contractTerm': _term,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu hợp đồng.')),
      );
      _formKey.currentState!.reset();
      _fullName.clear();
      _cccd.clear();
      _address.clear();
      _phone.clear();
      setState(() {
        _startDate = DateTime.now();
        _term = 1;
      });
      if (!widget.embedded) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Thông tin hợp đồng',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Nhập thông tin và gửi cho chủ nhà/quản lý duyệt.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _fullName,
            decoration: const InputDecoration(labelText: 'Họ và tên'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cccd,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số CCCD'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Số điện thoại'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Địa chỉ thường trú'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            title: const Text('Ngày bắt đầu'),
            subtitle: Text(
              '${_startDate.day.toString().padLeft(2, '0')}/${_startDate.month.toString().padLeft(2, '0')}/${_startDate.year}',
            ),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _term,
            decoration: const InputDecoration(labelText: 'Thời hạn hợp đồng'),
            items: [
              for (var i = 1; i <= 10; i++)
                DropdownMenuItem(value: i, child: Text('$i năm')),
            ],
            onChanged: (value) => setState(() => _term = value ?? 1),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.send_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_saving ? 'Đang gửi...' : 'Gửi yêu cầu'),
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: const Text('Tạo hợp đồng')),
      body: body,
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? 'Vui lòng nhập thông tin'
      : null;
}
