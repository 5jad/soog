import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { useApp } from './ctx';
import Header from './components/Header';
import BottomNav from './components/BottomNav';
import Promo from './components/Promo';
import CartDrawer from './components/CartDrawer';
import ProductModal from './components/ProductModal';
import LoginModal from './components/LoginModal';
import Home from './pages/Home';
import StorePage from './pages/StorePage';
import ProductsPage from './pages/ProductsPage';
import Favorites from './pages/Favorites';
import Orders from './pages/Orders';
import Profile from './pages/Profile';
import Checkout from './pages/Checkout';

export default function App() {
  const { toast, prodId, setProdId, cartOpen, setCartOpen, loginOpen, setLoginOpen } = useApp();
  return (
    <>
      <Header />
      <main id="screen">
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/stores/:id" element={<StorePage />} />
          <Route path="/stores" element={<ProductsPage mode="stores" />} />
          <Route path="/prods" element={<ProductsPage mode="prods" />} />
          <Route path="/offers" element={<ProductsPage mode="offers" />} />
          <Route path="/search" element={<ProductsPage mode="search" />} />
          <Route path="/fav" element={<Favorites />} />
          <Route path="/orders" element={<Orders />} />
          <Route path="/profile" element={<Profile />} />
          <Route path="/checkout" element={<Checkout />} />
        </Routes>
      </main>
      <footer className="foot">
        <div><b>زبون</b> — منصة متاجر محافظة واسط (الكوت)</div>
        <div className="foot-links">
          <a href="/">الصفحة الرسمية</a> ·
          <a href="https://t.me/soog_otp_bot">بوت الإشعارات</a> ·
          <a href="/admin">لوحة الأدمن</a>
        </div>
      </footer>

      <CartDrawer open={cartOpen} onClose={() => setCartOpen(false)} />
      <ProductModal id={prodId} onClose={() => setProdId(null)} />
      <LoginModal open={loginOpen} onClose={() => setLoginOpen(false)} />
      <BottomNav />
      {toast && <div className={`toast ${toast.kind}`}>{toast.msg}</div>}
    </>
  );
}