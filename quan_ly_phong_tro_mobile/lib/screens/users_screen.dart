import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/app_user.dart';
import 'user_form_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, required this.api, required this.user});

  final ApiClient api;
  final AppUser user;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<AppUser> _users = const [];
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
      final data = await widget.api.get('/users') as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _users = data
            .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không tải được danh sách tài khoản.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm({AppUser? user}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserFormScreen(api: widget.api, user: user),
      ),
    );
    if (changed == true) _load();
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
        child: _users.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('Chưa có tài khoản.')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: _users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) {
                  final user = _users[index];
                  return Card(
                    child: ListTile(
                      onTap: () => _openForm(user: user),
                      leading: CircleAvatar(
                        child: Text(
                          (user.fullName?.trim().isNotEmpty == true
                                  ? user.fullName!
                                  : user.username)
                              .substring(0, 1)
                              .toUpperCase(),
                        ),
                      ),
                      title: Text(
                        user.fullName?.trim().isNotEmpty == true
                            ? user.fullName!
                            : user.username,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${user.username} • ${_roleLabel(user.role)}${user.roomName != null ? ' • ${user.roomName}' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Tạo tài khoản'),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Chủ nhà';
      case 'manager':
        return 'Quản lý';
      default:
        return 'Người thuê';
    }
  }
}
