import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../models/app_user.dart';
import 'contracts_screen.dart';
import 'dashboard_screen.dart';
import 'invoices_screen.dart';
import 'login_screen.dart';
import 'rooms_screen.dart';
import 'users_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.api, required this.user});

  final ApiClient api;
  final AppUser user;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _TabSpec {
  final String label;
  final IconData icon;
  final Widget Function() page;

  const _TabSpec(this.label, this.icon, this.page);
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  List<_TabSpec> get _tabs {
    final tabs = <_TabSpec>[
      _TabSpec(
        'Tổng quan',
        Icons.dashboard_outlined,
        () => DashboardScreen(api: widget.api, user: widget.user),
      ),
      _TabSpec(
        'Phòng',
        Icons.meeting_room_outlined,
        () => RoomsScreen(api: widget.api, user: widget.user),
      ),
      _TabSpec(
        'Hóa đơn',
        Icons.receipt_long_outlined,
        () => InvoicesScreen(api: widget.api, user: widget.user),
      ),
      _TabSpec(
        'Hợp đồng',
        Icons.description_outlined,
        () => ContractsScreen(api: widget.api, user: widget.user),
      ),
    ];
    if (widget.user.isOwner) {
      tabs.add(
        _TabSpec(
          'Tài khoản',
          Icons.manage_accounts_outlined,
          () => UsersScreen(api: widget.api, user: widget.user),
        ),
      );
    }
    return tabs;
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có muốn đăng xuất khỏi ứng dụng không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await widget.api.post('/auth/logout');
    } catch (_) {
      // Vẫn cho phép thoát ứng dụng nếu backend không phản hồi.
    }
    widget.api.clearSession();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => LoginScreen(api: widget.api)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    if (_index >= tabs.length) _index = 0;
    final tab = tabs[_index];

    return Scaffold(
      appBar: AppBar(
        title: Text(tab.label),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(
                widget.user.fullName?.trim().isNotEmpty == true
                    ? widget.user.fullName!
                    : widget.user.username,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: KeyedSubtree(
        key: ValueKey('${tab.label}-$_index'),
        child: tab.page(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          for (final item in tabs)
            NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.icon),
              label: item.label,
            ),
        ],
      ),
    );
  }
}
