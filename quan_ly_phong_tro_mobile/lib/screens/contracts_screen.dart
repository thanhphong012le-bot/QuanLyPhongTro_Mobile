import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../models/app_user.dart';
import '../models/contract.dart';
import 'contract_form_screen.dart';

class ContractsScreen extends StatefulWidget {
  const ContractsScreen({super.key, required this.api, required this.user});

  final ApiClient api;
  final AppUser user;

  @override
  State<ContractsScreen> createState() => _ContractsScreenState();
}

class _ContractsScreenState extends State<ContractsScreen> {
  List<ContractModel> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.user.canManageContracts) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get('/contracts') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _items = data
            .map(
              (e) => ContractModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không tải được hợp đồng.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(ContractModel contract) async {
    try {
      await widget.api.post('/contracts/${contract.id}/approve');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã duyệt hợp đồng.')),
      );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _delete(ContractModel contract) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa hợp đồng'),
        content: Text('Xóa yêu cầu hợp đồng của ${contract.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.delete('/contracts/${contract.id}');
      if (!mounted) return;
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.canManageContracts) {
      return ContractFormScreen(api: widget.api, embedded: true);
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: FilledButton.tonalIcon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(_error!),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: _items.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 180),
                Center(child: Text('Chưa có yêu cầu hợp đồng.')),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final item = _items[index];
                final approved = item.status.toLowerCase() == 'approved';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.fullName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Chip(
                              label: Text(approved ? 'Đã duyệt' : 'Chờ duyệt'),
                              backgroundColor: approved
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('CCCD: ${item.cccd}'),
                        Text('Điện thoại: ${item.phoneNumber}'),
                        Text('Địa chỉ: ${item.address}'),
                        const SizedBox(height: 5),
                        Text(
                          '${formatDate(item.startDate)} → ${formatDate(item.endDate)} (${item.contractTerm} năm)',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (!approved)
                              FilledButton.tonalIcon(
                                onPressed: () => _approve(item),
                                icon: const Icon(Icons.check),
                                label: const Text('Duyệt'),
                              ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Xóa',
                              onPressed: () => _delete(item),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
