import { createClient } from '@supabase/supabase-js';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_KEY } from 'astro:env/client';

/**
 * Cliente con la clave pública. Respeta RLS: solo puede hacer lo que las
 * políticas permiten al usuario anónimo. Sirve en servidor y en navegador.
 * El cliente con sesión (cookies, @supabase/ssr) llega en la etapa 5.
 */
export const supabase = createClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});
