import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  base: '/plugins/socops/',
  plugins: [react()],
  build: {
    manifest: true,
    outDir: '../public',
    emptyOutDir: true,
    assetsDir: 'assets',
    rollupOptions: {
      input: 'src/main.tsx',
    },
  },
});
