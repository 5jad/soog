import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'api.dart';
import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'theme.dart';

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
      title: 'زبون — الكوت',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
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
