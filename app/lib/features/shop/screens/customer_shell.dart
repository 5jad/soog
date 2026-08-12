import 'package:flutter/material.dart';
import 'package:zaboon/core/api/api.dart';
import 'package:zaboon/core/theme/zaboon_design_system.dart';
import 'package:zaboon/core/widgets/widgets.dart';
import 'package:zaboon/features/shop/screens/stores_screen.dart';
import 'package:zaboon/features/shop/screens/store_screen.dart';
import 'package:zaboon/features/shop/screens/favorites_screen.dart';
import 'package:zaboon/features/shop/screens/search_screen.dart';
import 'package:zaboon/features/auth/screens/account_screen.dart';
import 'package:zaboon/features/shop/screens/home_screen.dart';
import 'package:zaboon/features/shop/screens/product_screen.dart';

class CustomerShell extends StatefulWidget {
  final List<String> roles;
  const CustomerShell({super.key, required this.roles});
  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int tab = 0;
  final GlobalKey<HomeScreenState> homeKey = GlobalKey();

  /// عند الضغط على أيقونة «الرئيسية»: جلب جديد صامت + رجوع لأعلى الصفحة
  void _goHome() {
    final h = homeKey.currentState;
    h?.refresh(); // بيانات جديدة من السيرفر (بدون إظهار الـ loading)
    h?.scrollTop();
  }

  @override
  void initState() {
    super.initState();
    // العداد يظهر فوراً من الذاكرة ثم يتزامن من السيرفر للمسجل
    AppState.i.loadCart();
    if (Api.logged) {
      Api.get('/api/customer/cart')
          .then((d) {
            final items = d['cart'] ?? d['items'] ?? [];
            AppState.i.setCart((items as List).length);
          })
          .catchError((_) {});
      Api.get('/api/customer/favorites')
          .then((d) {
            final favs = d['products'] ?? [];
            AppState.i.favsCount.value = (favs as List).length;
          })
          .catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(key: homeKey, onGoStore: (id) => pushStore(context, id)),
      StoresScreen(onOpen: (s) => pushStore(context, s.id)),
      const SearchScreen(),
      const FavoritesScreen(),
      AccountScreen(roles: widget.roles),
    ];
    return Scaffold(
      body: Stack(
        children: [
          _PageStack(tab: tab, children: pages),
          // زر السلة العائم — يظهر فوق كل التبويبات عند وجود أغراض (ويتحرك حسب السلة)
          const FloatingCartFab(bottom: 84),
        ],
      ),
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: AppState.i.favsCount,
        builder: (_, favs, __) => GlassBottomNav(
          index: tab,
          badgeIndex: null,
          extraBadges: {3: favs},
          items: const [
            (Icons.home_rounded, 'الرئيسية'),
            (Icons.storefront_rounded, 'المتاجر'),
            (Icons.search_rounded, 'بحث'),
            (Icons.favorite_rounded, 'المفضلة'),
            (Icons.person_rounded, 'حسابي'),
          ],
          onTap: (i) {
            if (i == 0) {
              // الضغط على الرئيسية: ننتقل إليها + رفريش + رجوع للأعلى دائماً
              if (tab != 0) setState(() => tab = 0);
              _goHome();
              return;
            }
            setState(() {
              tab = i;
              if (i == 3) AppState.i.favsReload.value++;
            });
          },
        ),
      ),
    );
  }
}

void pushStore(BuildContext context, int id) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => StoreScreen(storeId: id)),
  );
}

/// انتقال ناعم بين التبويبات (بدل الانقلاب الفوري) — 280ms fade + سلايد باتجاه التبويب الجديد
/// ويحفظ حالة كل تبويب حية لأن IndexedStack تبقى هي الحاوية
class _PageStack extends StatefulWidget {
  final int tab;
  final List<Widget> children;
  const _PageStack({required this.tab, required this.children});

  @override
  State<_PageStack> createState() => _PageStackState();
}

class _PageStackState extends State<_PageStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
    value: 1,
  );
  int _prev = 0;

  @override
  void initState() {
    super.initState();
    _prev = widget.tab;
  }

  @override
  void didUpdateWidget(_PageStack old) {
    super.didUpdateWidget(old);
    if (widget.tab != old.tab) {
      _prev = old.tab;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = widget.tab > _prev ? 1.0 : -1.0;
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(
          begin: Offset(dir * 0.07, 0),
          end: Offset.zero,
        ).animate(curved),
        child: IndexedStack(index: widget.tab, children: widget.children),
      ),
    );
  }
}

