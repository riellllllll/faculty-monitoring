import { defineConfig } from 'vite';

export default defineConfig({
  root: '.',
  base: '/',
  publicDir: false,
  build: {
    outDir: 'public/app',
    emptyOutDir: true,
    assetsDir: 'assets',
  },
  server: {
    host: '0.0.0.0',
    port: 5173,
    strictPort: true,
    fs: {
      deny: [
        '.env', '.env.*', '*.{crt,pem,key,p12,pfx,cer,der}',
        '.npmrc', '.yarnrc.yml', '**/.git/**',
        '**/*.php', '**/*.sql',
        '**/app/**', '**/config/**', '**/database/**',
        '**/storage/**', '**/vendor/**', '**/tests/**',
      ],
    },
    proxy: {
      '/api': {
        target: 'https://faculty-monitor.local',
        changeOrigin: true,
        secure: false,
        configure(proxy) {
          // Vite serves local phones over HTTP; the HTTPS upstream's Secure cookie
          // cannot be returned by that browser. This rewrite applies only here.
          proxy.on('proxyRes', response => {
            const cookies = response.headers['set-cookie'];
            if (cookies) response.headers['set-cookie'] = cookies.map(cookie =>
              cookie.replace(/;\s*Secure(?=;|$)/gi, ''));
          });
        },
      },
    },
  },
});
