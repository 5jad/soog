import 'package:flutter/material.dart';
import '../api.dart';
import 'customer_shell.dart';
import 'vendor_shell.dart';
import 'delivery_shell.dart';
import 'admin_shell.dart';

/// الغلاف الرئيسي — يوجّه حسب دور المستخدم
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  String role = Api.me?['role'] ?? 'customer';

  @override
  Widget build(BuildContext context) {
    if (role == 'vendor') return VendorShell(onExit: _logout);
    if (role == 'delivery') return DeliveryShell(onExit: _logout);
    if (role == 'admin') return AdminShell(onExit: _logout);
    return CustomerShell(roles: rolesOf(Api.me));
  }

  Future<void> _logout() async {
    await Api.clear();
    if (mounted) Navigator.pushReplacementNamed(context, '/');
  }

  List<String> rolesOf(dynamic me) {
    final r = <String>['customer'];
    final u = me as Map<String, dynamic>?;
    if (u != null) {
      if (u['role'] == 'vendor' || u['is_vendor'] == true) r.add('vendor');
      if (u['role'] == 'delivery') r.add('delivery');
      if (u['role'] == 'admin') r.add('admin');
    }
    return r;
  }
}
