import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL } from 'astro:env/client';
import { SUPABASE_SECRET_KEY } from 'astro:env/server';

/**
 * SOLO SERVIDOR. Usa la clave service role, que IGNORA RLS.
 * Úsalo únicamente en src/pages/api/, src/lib/server/ o el middleware, y solo
 * para operaciones que lo requieran (checkout, cotizaciones, panel admin).
 * Nunca lo importes desde un componente que se ejecute en el navegador.
 */
export const supabaseAdmin = createClient(PUBLIC_SUPABASE_URL, SUPABASE_SECRET_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});
