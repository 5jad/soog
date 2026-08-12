import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/routing/shell.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.load();
  AppState.i.refreshStores(); // عدد المتاجر للشريط العلوي — يعمل بالخلفية
  runApp(const ZaboonApp());
}

class ZaboonApp extends StatefulWidget {
  const ZaboonApp({super.key});
  @override
  State<ZaboonApp> createState() => _ZaboonAppState();
}

class _ZaboonAppState extends State<ZaboonApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'زبون',
      debugShowCheckedModeBanner: false,
      theme: buildZaboonTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Shell(),
    );
  }
}
