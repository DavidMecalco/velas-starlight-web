-- =====================================================================
-- VELAS STARLIGHT: esquema inicial para Supabase (Postgres)
-- Moneda: MXN. Precios en numeric(10,2).
-- Ejecutar completo en: Supabase > SQL Editor > New query
-- =====================================================================

-- ---------- 1. TIPOS (ENUMS) ----------
create type public.user_role      as enum ('customer', 'admin');
create type public.product_kind   as enum ('vela', 'belleza', 'insumo', 'molde');
create type public.order_status   as enum ('pending', 'paid', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded');
create type public.payment_status as enum ('pending', 'approved', 'rejected', 'refunded');
create type public.quote_status   as enum ('new', 'contacted', 'quoted', 'closed');

-- ---------- 2. FUNCIONES AUXILIARES ----------
-- Actualiza updated_at automáticamente
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ---------- 3. PERFILES (extiende auth.users) ----------
create table public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  full_name  text,
  phone      text,
  avatar_url text,
  role       public.user_role not null default 'customer',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();

-- Crea el perfil automáticamente cuando alguien se registra (Google incluido)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, email, full_name, avatar_url)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ¿El usuario actual es admin? (security definer evita recursión con RLS)
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- ---------- 4. DIRECCIONES ----------
create table public.addresses (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  label       text,                       -- "Casa", "Trabajo"
  recipient   text not null,
  phone       text not null,
  street      text not null,
  ext_number  text,
  int_number  text,
  neighborhood text not null,             -- colonia
  city        text not null,
  state       text not null,
  postal_code text not null,
  country     text not null default 'MX',
  reference   text,
  is_default  boolean not null default false,
  created_at  timestamptz not null default now()
);
create index on public.addresses (user_id);

-- ---------- 5. CATÁLOGO ----------
create table public.categories (
  id         uuid primary key default gen_random_uuid(),
  slug       text not null unique,
  name       text not null,
  kind       public.product_kind not null,
  parent_id  uuid references public.categories(id) on delete set null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table public.products (
  id           uuid primary key default gen_random_uuid(),
  slug         text not null unique,            -- URL: /productos/vela-angel
  name         text not null,
  short_description text,
  description  text,
  kind         public.product_kind not null,
  category_id  uuid references public.categories(id) on delete set null,
  -- Etiquetas que ya usas en tu diseño
  is_new       boolean not null default false,
  is_bestseller boolean not null default false,
  is_featured  boolean not null default false,
  is_active    boolean not null default true,   -- false = oculto (borrador)
  -- Atributos propios por tipo, ej:
  --  vela:   {"cera":"soya","duracion_horas":40,"aroma_notas":["vainilla","ámbar"]}
  --  molde:  {"material":"PLA","medidas_mm":"80x60x50","apto_para":"cera/yeso"}
  --  insumo: {"presentacion":"bolsa","pureza":"..."}
  attributes   jsonb not null default '{}'::jsonb,
  seo_title    text,
  seo_description text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index on public.products (category_id);
create index on public.products (kind) where is_active;
create trigger trg_products_updated before update on public.products
  for each row execute function public.set_updated_at();

-- Variantes: aroma, tamaño, color, presentación. Aquí viven precio y stock.
create table public.product_variants (
  id             uuid primary key default gen_random_uuid(),
  product_id     uuid not null references public.products(id) on delete cascade,
  sku            text not null unique,
  name           text not null,                 -- "Lavanda / 200 g"
  options        jsonb not null default '{}'::jsonb,  -- {"aroma":"Lavanda","tamano":"200 g"}
  price          numeric(10,2) not null check (price >= 0),
  compare_at_price numeric(10,2) check (compare_at_price >= 0),  -- precio tachado
  stock          int not null default 0 check (stock >= 0),
  weight_grams   int check (weight_grams >= 0), -- clave para calcular envío
  is_active      boolean not null default true,
  sort_order     int not null default 0,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
create index on public.product_variants (product_id);
create trigger trg_variants_updated before update on public.product_variants
  for each row execute function public.set_updated_at();

create table public.product_images (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  variant_id uuid references public.product_variants(id) on delete set null,
  url        text not null,                     -- URL de Supabase Storage
  alt        text,
  sort_order int not null default 0
);
create index on public.product_images (product_id);

-- Descuentos por mayoreo (que ya mencionas en tu página de contacto)
create table public.wholesale_tiers (
  id          uuid primary key default gen_random_uuid(),
  variant_id  uuid not null references public.product_variants(id) on delete cascade,
  min_qty     int not null check (min_qty > 1),
  unit_price  numeric(10,2) not null check (unit_price >= 0),
  unique (variant_id, min_qty)
);

-- ---------- 6. PEDIDOS ----------
create sequence public.order_number_seq start 1001;

create table public.orders (
  id            uuid primary key default gen_random_uuid(),
  order_number  bigint not null unique default nextval('public.order_number_seq'),
  user_id       uuid references public.profiles(id) on delete set null,  -- null = invitado
  email         text not null,
  phone         text,
  status        public.order_status not null default 'pending',
  subtotal      numeric(10,2) not null check (subtotal >= 0),
  shipping_cost numeric(10,2) not null default 0 check (shipping_cost >= 0),
  discount      numeric(10,2) not null default 0 check (discount >= 0),
  total         numeric(10,2) not null check (total >= 0),
  currency      text not null default 'MXN',
  -- Foto de la dirección al momento de comprar (no cambia si el cliente edita la suya)
  shipping_address jsonb not null,
  shipping_carrier text,
  tracking_number  text,
  customer_notes   text,
  internal_notes   text,
  requires_invoice boolean not null default false,   -- CFDI
  billing_data     jsonb,                            -- RFC, razón social, régimen, uso CFDI
  paid_at       timestamptz,
  shipped_at    timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index on public.orders (user_id);
create index on public.orders (status);
create trigger trg_orders_updated before update on public.orders
  for each row execute function public.set_updated_at();

create table public.order_items (
  id          uuid primary key default gen_random_uuid(),
  order_id    uuid not null references public.orders(id) on delete cascade,
  variant_id  uuid references public.product_variants(id) on delete set null,
  -- Snapshot: si cambias nombre o precio después, el pedido histórico no se altera
  product_name text not null,
  variant_name text not null,
  sku         text not null,
  unit_price  numeric(10,2) not null check (unit_price >= 0),
  quantity    int not null check (quantity > 0),
  line_total  numeric(10,2) generated always as (unit_price * quantity) stored
);
create index on public.order_items (order_id);

-- Pagos: un pedido puede tener varios intentos
create table public.payments (
  id                  uuid primary key default gen_random_uuid(),
  order_id            uuid not null references public.orders(id) on delete cascade,
  provider            text not null,            -- 'mercadopago' | 'stripe' | 'conekta'
  provider_payment_id text not null,
  status              public.payment_status not null default 'pending',
  method              text,                     -- card, oxxo, spei
  amount              numeric(10,2) not null,
  currency            text not null default 'MXN',
  raw_payload         jsonb,                    -- respuesta del webhook, para auditoría
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (provider, provider_payment_id)        -- evita procesar el mismo webhook dos veces
);
create index on public.payments (order_id);
create trigger trg_payments_updated before update on public.payments
  for each row execute function public.set_updated_at();

-- ---------- 7. COTIZACIONES (formulario de contacto: eventos, bodas, mayoreo) ----------
create table public.quote_requests (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  email       text not null,
  phone       text,
  company     text,
  request_type text not null default 'general', -- evento, boda, mayoreo, general
  event_date  date,
  quantity_estimate int,
  message     text not null,
  status      public.quote_status not null default 'new',
  created_at  timestamptz not null default now()
);

-- ---------- 8. RESEÑAS (prueba social real) ----------
create table public.reviews (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references public.products(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  rating      int not null check (rating between 1 and 5),
  title       text,
  body        text,
  is_approved boolean not null default false,   -- moderación antes de publicar
  created_at  timestamptz not null default now(),
  unique (product_id, user_id)
);
create index on public.reviews (product_id) where is_approved;

-- =====================================================================
-- 9. SEGURIDAD: ROW LEVEL SECURITY
-- Regla general: el checkout y los webhooks usan la service_role key
-- desde el servidor (Astro), que ignora RLS. El navegador solo hace
-- lo que estas políticas permiten.
-- =====================================================================
alter table public.profiles         enable row level security;
alter table public.addresses        enable row level security;
alter table public.categories       enable row level security;
alter table public.products         enable row level security;
alter table public.product_variants enable row level security;
alter table public.product_images   enable row level security;
alter table public.wholesale_tiers  enable row level security;
alter table public.orders           enable row level security;
alter table public.order_items      enable row level security;
alter table public.payments         enable row level security;
alter table public.quote_requests   enable row level security;
alter table public.reviews          enable row level security;

-- Perfiles: cada quien ve y edita el suyo; el rol NO se puede cambiar desde el cliente
create policy "perfil: ver propio"   on public.profiles for select using (id = auth.uid() or public.is_admin());
create policy "perfil: editar propio" on public.profiles for update using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.profiles from authenticated;
grant  update (full_name, phone, avatar_url) on public.profiles to authenticated;

-- Direcciones: solo las propias
create policy "direcciones: propias" on public.addresses for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Catálogo: lectura pública de lo activo; escritura solo admin
create policy "categorias: lectura publica" on public.categories for select using (true);
create policy "categorias: admin"           on public.categories for all using (public.is_admin()) with check (public.is_admin());

create policy "productos: lectura publica" on public.products for select using (is_active or public.is_admin());
create policy "productos: admin"           on public.products for all using (public.is_admin()) with check (public.is_admin());

create policy "variantes: lectura publica" on public.product_variants for select using (is_active or public.is_admin());
create policy "variantes: admin"           on public.product_variants for all using (public.is_admin()) with check (public.is_admin());

create policy "imagenes: lectura publica"  on public.product_images for select using (true);
create policy "imagenes: admin"            on public.product_images for all using (public.is_admin()) with check (public.is_admin());

create policy "mayoreo: lectura publica"   on public.wholesale_tiers for select using (true);
create policy "mayoreo: admin"             on public.wholesale_tiers for all using (public.is_admin()) with check (public.is_admin());

-- Pedidos: el cliente solo LEE los suyos. Crear/actualizar lo hace el servidor.
create policy "pedidos: ver propios" on public.orders for select using (user_id = auth.uid() or public.is_admin());
create policy "pedidos: admin edita" on public.orders for update using (public.is_admin()) with check (public.is_admin());

create policy "items: ver propios" on public.order_items for select using (
  public.is_admin() or exists (
    select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid()
  )
);

create policy "pagos: ver propios" on public.payments for select using (
  public.is_admin() or exists (
    select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid()
  )
);

-- Cotizaciones: cualquiera puede enviar; solo admin lee
-- (añade captcha o límite de envíos en el servidor para evitar spam)
create policy "cotizaciones: enviar"    on public.quote_requests for insert with check (true);
create policy "cotizaciones: admin ver" on public.quote_requests for select using (public.is_admin());
create policy "cotizaciones: admin edit" on public.quote_requests for update using (public.is_admin()) with check (public.is_admin());

-- Reseñas: públicas solo las aprobadas; el usuario crea las suyas (quedan pendientes)
create policy "resenas: ver aprobadas" on public.reviews for select using (is_approved or user_id = auth.uid() or public.is_admin());
create policy "resenas: crear propia"  on public.reviews for insert with check (user_id = auth.uid() and is_approved = false);
create policy "resenas: admin"         on public.reviews for all using (public.is_admin()) with check (public.is_admin());

-- =====================================================================
-- 10. DATOS INICIALES DE EJEMPLO (opcional, borra lo que no quieras)
-- =====================================================================
insert into public.categories (slug, name, kind, sort_order) values
  ('velas',    'Velas',    'vela',    1),
  ('belleza',  'Belleza',  'belleza', 2),
  ('insumos',  'Insumos',  'insumo',  3),
  ('moldes-3d','Moldes 3D','molde',   4);

-- Para convertirte en administrador, después de iniciar sesión una vez:
-- update public.profiles set role = 'admin' where email = 'TU_CORREO@gmail.com';

-- Imágenes: crea en Storage un bucket público llamado "products"
-- y guarda aquí la URL pública de cada archivo.
