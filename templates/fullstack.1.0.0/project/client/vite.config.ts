import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // forward /api to the API so the page can call it without CORS
    proxy: { '/api': 'http://localhost:{__port__}' },
  },
})
