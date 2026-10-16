import path from 'node:path'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') },
  },
  build: {
    // two pages: the front page, and /changelog/
    rollupOptions: {
      input: {
        main: path.resolve(__dirname, 'index.html'),
        changelog: path.resolve(__dirname, 'changelog/index.html'),
      },
    },
  },
})
