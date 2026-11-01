import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../models/app_user.dart';
import '../models/invoice.dart';
import 'invoice_form_screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key, required this.api, required this.user});

  final ApiClient api;
  final AppUser user;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<Invoice> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get('/invoices') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _items = data
            .map((e) => Invoice.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không tải được danh sách hóa đơn.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createInvoice() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => InvoiceFormScreen(api: widget.api)),
    );
    if (changed == true) _load();
  }

  Future<void> _markPaid(Invoice invoice) async {
    try {
      await widget.api.post('/invoices/${invoice.id}/pay');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật trạng thái thanh toán.')),
      );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  void _showDetails(Invoice invoice) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${invoice.roomName ?? 'Phòng'} - Tháng ${invoice.month}/${invoice.year}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 16),
              _detail('Người thuê', invoice.tenantUsername ?? 'Chưa gán'),
              _detail('Điện', '${invoice.electricOld} → ${invoice.electricNew}'),
              _detail('Nước', '${invoice.waterOld} → ${invoice.waterNew}'),
              _detail('Tổng tiền', formatVnd(invoice.totalAmount)),
              _detail('Trạng thái', invoice.isPaid ? 'Đã thanh toán' : 'Chưa thanh toán'),
              if (invoice.createdDate != null)
                _detail('Ngày tạo', formatDate(invoice.createdDate!)),
              if (!invoice.isPaid) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _markPaid(invoice);
                    },
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      widget.user.isTenant
                          ? 'Xác nhận đã thanh toán'
                          : 'Đánh dấu đã thanh toán',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('Chưa có hóa đơn nào.')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: _items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final invoice = _items[index];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showDetails(invoice),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: invoice.isPaid
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              child: Icon(
                                invoice.isPaid
                                    ? Icons.check_circle_outline
                                    : Icons.receipt_long_outlined,
                                color: invoice.isPaid
                                    ? Colors.green.shade700
                                    : Colors.orange.shade800,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invoice.roomName ?? 'Phòng ${invoice.roomId}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Tháng ${invoice.month}/${invoice.year}'),
                                  if (invoice.tenantUsername?.isNotEmpty == true) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      'Người thuê: ${invoice.tenantUsername}',
                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                    ),
                                  ],
                                  const SizedBox(height: 5),
                                  Text(
                                    formatVnd(invoice.totalAmount),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              invoice.isPaid ? 'Đã trả' : 'Chưa trả',
                              style: TextStyle(
                                color: invoice.isPaid
                                    ? Colors.green.shade700
                                    : Colors.orange.shade800,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: widget.user.canManageInvoices
          ? FloatingActionButton.extended(
              onPressed: _createInvoice,
              icon: const Icon(Icons.add),
              label: const Text('Tạo hóa đơn'),
            )
          : null,
    );
  }
}
