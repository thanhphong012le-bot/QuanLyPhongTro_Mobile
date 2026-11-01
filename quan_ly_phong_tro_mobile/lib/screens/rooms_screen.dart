import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../models/app_user.dart';
import '../models/room.dart';
import 'room_form_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key, required this.api, required this.user});

  final ApiClient api;
  final AppUser user;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List<Room> _rooms = const [];
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
      final data = await widget.api.get('/rooms') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _rooms = data
            .map((e) => Room.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không tải được danh sách phòng.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({Room? room}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoomFormScreen(api: widget.api, room: room),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(Room room) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa phòng'),
        content: Text('Bạn chắc chắn muốn xóa ${room.roomName}?'),
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
      await widget.api.delete('/rooms/${room.id}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa phòng.')),
      );
      _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
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
        child: _rooms.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('Chưa có phòng nào.')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: _rooms.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final room = _rooms[index];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: widget.user.canManageRooms
                          ? () => _openForm(room: room)
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              child: Text(
                                room.roomName.replaceAll(RegExp(r'[^0-9]'), '')
                                        .isNotEmpty
                                    ? room.roomName
                                        .replaceAll(RegExp(r'[^0-9]'), '')
                                    : 'P',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          room.roomName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                      ),
                                      _StatusChip(isEmpty: room.isEmpty),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${formatVnd(room.price)} / tháng',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    room.tenantUsername?.isNotEmpty == true
                                        ? 'Người thuê: ${room.tenantUsername}'
                                        : 'Chưa gán người thuê',
                                    style: const TextStyle(color: Colors.black54),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'Điện ${formatVnd(room.electricPrice)} • Nước ${formatVnd(room.waterPrice)}${room.hasWifi ? ' • Có WiFi' : ''}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            if (widget.user.isOwner)
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _openForm(room: room);
                                  if (value == 'delete') _delete(room);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Sửa'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Xóa'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: widget.user.isOwner
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Thêm phòng'),
            )
          : null,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isEmpty});

  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isEmpty ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isEmpty ? 'Trống' : 'Đang thuê',
        style: TextStyle(
          color: isEmpty ? Colors.green.shade700 : Colors.orange.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
