import { createRouter, createWebHashHistory } from 'vue-router';

/* ═══ المسارات — كل فئات الصفحات الـ 21 ═══
   Hash history: الموقع يُقدَّم ملفات ثابتة تحت /store — لا إعادة كتابة خادم */

const router = createRouter({
  history: createWebHashHistory(),
  scrollBehavior(_to, _from, saved) {
    if (saved) return saved;
    return { top: 0 };
  },
  routes: [
    { path: '/', name: 'home', component: () => import('../views/HomeView.vue'), meta: { title: 'الرئيسية' } },
    { path: '/cart', name: 'cart', component: () => import('../views/CartView.vue'), meta: { title: 'السلة' } },
    { path: '/product/:id', name: 'product', component: () => import('../views/ProductView.vue'), meta: { title: 'المنتج' } },
    { path: '/stores', name: 'stores', component: () => import('../views/StoresView.vue'), meta: { title: 'المتاجر' } },
    { path: '/stores/:id', name: 'store', component: () => import('../views/StoreView.vue'), meta: { title: 'المتجر' } },
    { path: '/prods', name: 'prods', component: () => import('../views/ProductsView.vue'), meta: { mode: 'all', title: 'كل المنتجات' } },
    { path: '/cat/:id', name: 'cat', component: () => import('../views/ProductsView.vue'), meta: { mode: 'cat' }, props: true },
    { path: '/search', name: 'search', component: () => import('../views/ProductsView.vue'), meta: { mode: 'search', title: 'البحث' } },
    { path: '/offers', name: 'offers', component: () => import('../views/ProductsView.vue'), meta: { mode: 'offers', title: 'العروض' } },
    { path: '/checkout', name: 'checkout', component: () => import('../views/CheckoutView.vue'), meta: { title: 'إتمام الطلب' } },
    { path: '/orders', name: 'orders', component: () => import('../views/OrdersView.vue'), meta: { title: 'طلباتي' } },
    { path: '/orders/:id', name: 'order', component: () => import('../views/OrderDetailView.vue'), meta: { title: 'تفاصيل الطلب' } },
    { path: '/orders/:id/track', name: 'track', component: () => import('../views/TrackView.vue'), meta: { title: 'تتبع الطلب' } },
    { path: '/chat', name: 'chat', component: () => import('../views/ChatView.vue'), meta: { title: 'الدردشة' } },
    { path: '/points', name: 'points', component: () => import('../views/PointsView.vue'), meta: { title: 'نقاطي' } },
    { path: '/notifications', name: 'notifications', component: () => import('../views/NotificationsView.vue'), meta: { title: 'الإشعارات' } },
    { path: '/fav', name: 'fav', component: () => import('../views/FavoritesView.vue'), meta: { title: 'المفضلة' } },
    { path: '/account', name: 'account', component: () => import('../views/AccountView.vue'), meta: { title: 'حسابي' } },
    { path: '/logout', name: 'logout', component: () => import('../views/LogoutView.vue'), meta: { title: 'خروج' } },
    { path: '/vendor', name: 'vendor', component: () => import('../views/VendorView.vue'), meta: { title: 'لوحة التاجر' } },
    { path: '/delivery', name: 'delivery', component: () => import('../views/DeliveryView.vue'), meta: { title: 'لوحة المندوب' } },
    { path: '/admin', name: 'admin', component: () => import('../views/RedirectView.vue'), props: { url: '/admin' }, meta: { title: 'الأدمن' } },
    { path: '/:pathMatch(.*)*', name: 'notfound', component: () => import('../views/NotFoundView.vue'), meta: { title: 'غير موجود' } },
  ],
});

export default router;