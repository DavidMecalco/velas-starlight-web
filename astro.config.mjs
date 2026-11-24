// @ts-check
import { defineConfig, envField } from 'astro/config';
import node from '@astrojs/node';

// https://astro.build/config
export default defineConfig({
  // La mayoría de las páginas se generan en el servidor (ver docs/RUTAS.md).
  // Las estáticas declaran `export const prerender = true`.
  output: 'server',
  adapter: node({ mode: 'standalone' }),
  env: {
    schema: {
      PUBLIC_SUPABASE_URL: envField.string({ context: 'client', access: 'public', url: true }),
      PUBLIC_SUPABASE_KEY: envField.string({ context: 'client', access: 'public' }),
      // Clave service role: solo servidor. Astro impide importarla en código de navegador.
      SUPABASE_SECRET_KEY: envField.string({ context: 'server', access: 'secret' }),
    },
  },
});
