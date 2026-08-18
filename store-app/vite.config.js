import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

// ═══ إعداد البناء: مسارات نسبية لأن الموقع يُقدَّم من مجلد فرعي (/store) ═══
export default defineConfig({
  base: './',
  plugins: [vue()],
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
  },
});