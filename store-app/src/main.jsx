import React from 'react';
import { createRoot } from 'react-dom/client';
import { HashRouter } from 'react-router-dom';
import { AppProvider } from './ctx';
import App from './App';
import 'leaflet/dist/leaflet.css';
import './styles/tokens.css';
import './styles.css';

// لا تعرض أبداً نسخة قديمة عند الرجوع للصفحة من ذاكرة المتصفح
window.addEventListener('pageshow', (e) => {
  if (e.persisted) window.location.reload();
});

createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <AppProvider>
      <HashRouter>
        <App />
      </HashRouter>
    </AppProvider>
  </React.StrictMode>
);