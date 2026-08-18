import { createApp } from 'vue';
import router from './router';
import App from './App.vue';

/* ═══ ترتيب الاستيراد مهم: الملف المصدري أولاً ثم الباقي ═══ */
import './styles/tokens.css';
import './styles/base.css';
import './styles/layout.css';
import './styles/components.css';
import './styles/pages.css';

window.addEventListener('pageshow', (e) => {
  if (e.persisted) window.location.reload();
});

createApp(App).use(router).mount('#app');