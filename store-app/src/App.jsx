import React, { Suspense } from 'react';
import { Routes, Route } from 'react-router-dom';
import { useApp } from './ctx';
import Layout from './components/Layout';
import LoginModal from './components/LoginModal';
import { Loader } from './ui';

import Home from './pages/Home';
import CartPage from './pages/CartPage';
import ProductPage from './pages/ProductPage';
import StorePage from './pages/StorePage';
import StoresPage from './pages/StoresPage';
import ProductsPage from './pages/ProductsPage';
import Checkout from './pages/Checkout';
import Orders from './pages/Orders';
import OrderDetail from './pages/OrderDetail';
import Track from './pages/Track';
import ChatList from './pages/ChatList';
import Points from './pages/Points';
import Notifications from './pages/Notifications';
import Favorites from './pages/Favorites';
import Account from './pages/Account';
import Logout from './pages/Logout';
import VendorDashboard from './pages/VendorDashboard';
import DeliveryDashboard from './pages/DeliveryDashboard';
import ComingSoon from './pages/ComingSoon';

function AdminRedirect() {
  window.location.href = '/admin';
  return null;
}

export default function App() {
  const { toast, loginOpen, setLoginOpen } = useApp();
  return (
    <>
      <Layout />
      <main>
        <Suspense fallback={<Loader />}>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/cart" element={<CartPage />} />
            <Route path="/product/:id" element={<ProductPage />} />
            <Route path="/stores" element={<StoresPage />} />
            <Route path="/stores/:id" element={<StorePage />} />
            <Route path="/prods" element={<ProductsPage mode="all" />} />
            <Route path="/cat/:id" element={<ProductsPage mode="cat" />} />
            <Route path="/search" element={<ProductsPage mode="search" />} />
            <Route path="/offers" element={<ProductsPage mode="offers" />} />
            <Route path="/checkout" element={<Checkout />} />
            <Route path="/orders" element={<Orders />} />
            <Route path="/orders/:id" element={<OrderDetail />} />
            <Route path="/orders/:id/track" element={<Track />} />
            <Route path="/chat" element={<ChatList />} />
            <Route path="/points" element={<Points />} />
            <Route path="/notifications" element={<Notifications />} />
            <Route path="/fav" element={<Favorites />} />
            <Route path="/account" element={<Account />} />
            <Route path="/logout" element={<Logout />} />
            <Route path="/vendor" element={<VendorDashboard />} />
            <Route path="/delivery" element={<DeliveryDashboard />} />
            <Route path="/admin" element={<AdminRedirect />} />
          </Routes>
        </Suspense>
      </main>
      <LoginModal open={loginOpen} onClose={() => setLoginOpen(false)} />
      {toast && <div className={`toast ${toast.kind}`}>{toast.msg}</div>}
    </>
  );
}