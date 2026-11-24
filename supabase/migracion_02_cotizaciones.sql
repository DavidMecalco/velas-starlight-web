-- =====================================================================
-- MIGRACIÓN 02: cotizaciones con historial por cliente
-- Ejecutar DESPUÉS de schema_velas_starlight.sql y migracion_01.
--
-- Modelo:
--   customers        quién es el cliente (con o sin cuenta de Google)
--   quotes           cada cotización (cabecera) y su estado
--   quote_items      líneas de la cotización (copia de nombre y precio)
--   quote_documents  cada PDF generado (uno por revisión)
--   quote_messages   registro de envíos por correo o WhatsApp
--   orders.quote_id  el pedido nace de una cotización aceptada
-- =====================================================================

-- ---------- 0. ORDEN DE NOMBRES ----------
-- La tabla del formulario de contacto (eventos y mayoreo) se llamaba
-- quote_requests. Se renombra para no confundirla con las cotizaciones.
alter table public.quote_requests rename to inquiries;
alter type  public.quote_status   rename to inquiry_status;

-- ---------- 1. TIPOS ----------
create type public.quote_status as enum
  ('requested', 'sent', 'accepted', 'rejected', 'expired', 'cancelled');
-- requested = el cliente la solicitó (PDF preliminar)
-- sent      = tu esposa la revisó y la envió con precios finales
create type public.message_channel as enum ('email', 'whatsapp');
create type public.message_status  as enum ('queued', 'sent', 'failed');

-- ---------- 2. CLIENTES ----------
-- Un cliente puede existir sin cuenta (invitado). Cuando inicia sesión con
-- Google y el correo coincide, se enlaza solo y ve todo su historial.
create table public.customers (
  id         uuid primary key default gen_random_uuid(),
  profile_id uuid unique references public.profiles(id) on delete set null,
  name       text not null,
  email      text not null,
  phone      text not null,          -- obligatorio: se confirma por teléfono o WhatsApp
  company    text,
  notes      text,                   -- notas internas (solo admin)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index customers_email_key on public.customers (lower(email));
create trigger trg_customers_updated before update on public.customers
  for each row execute function public.set_updated_at();

-- Reemplaza el trigger de registro: además de crear el perfil, enlaza el
-- historial previo si el correo coincide y está verificado.
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

  if new.email is not null and new.email_confirmed_at is not null then
    update public.customers
       set profile_id = new.id
     where lower(email) = lower(new.email) and profile_id is null;
  end if;
  return new;
end $$;

-- ---------- 3. COTIZACIONES ----------
create sequence public.quote_number_seq start 1001;

create table public.quotes (
  id            uuid primary key default gen_random_uuid(),
  quote_number  bigint not null unique default nextval('public.quote_number_seq'),
  folio         text generated always as ('COT-' || quote_number::text) stored,
  customer_id   uuid not null references public.customers(id) on delete restrict,
  status        public.quote_status not null default 'requested',
  revision      int not null default 1,       -- sube cada vez que se regenera el PDF

  -- Enlace de acceso para invitados (sin cuenta). Largo e imposible de adivinar.
  access_token  text not null unique
                default replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''),

  -- Entrega solicitada
  delivery_method        public.delivery_method not null default 'delivery',
  delivery_zone_id       uuid references public.delivery_zones(id) on delete set null,
  shipping_address       jsonb,
  preferred_delivery_date date,
  preferred_time_window  text,
  payment_method         public.payment_method not null default 'cash',

  -- Importes
  subtotal         numeric(10,2) not null check (subtotal >= 0),
  shipping_cost    numeric(10,2) check (shipping_cost >= 0),   -- null = por confirmar
  shipping_pending boolean not null default false,
  discount         numeric(10,2) not null default 0 check (discount >= 0),
  total            numeric(10,2) not null check (total >= 0),
  currency         text not null default 'MXN',

  valid_until     timestamptz not null default (now() + interval '7 days'),  -- ajusta la vigencia
  customer_notes  text,
  internal_notes  text,
  sent_at         timestamptz,
  accepted_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index on public.quotes (customer_id, created_at desc);
create index on public.quotes (status);
create trigger trg_quotes_updated before update on public.quotes
  for each row execute function public.set_updated_at();

create table public.quote_items (
  id           uuid primary key default gen_random_uuid(),
  quote_id     uuid not null references public.quotes(id) on delete cascade,
  variant_id   uuid references public.product_variants(id) on delete set null,
  product_name text not null,
  variant_name text not null,
  sku          text not null,
  unit_price   numeric(10,2) not null check (unit_price >= 0),
  quantity     int not null check (quantity > 0),
  line_total   numeric(10,2) generated always as (unit_price * quantity) stored
);
create index on public.quote_items (quote_id);

-- Cada PDF generado queda guardado (Storage privado) y registrado aquí
create table public.quote_documents (
  id           uuid primary key default gen_random_uuid(),
  quote_id     uuid not null references public.quotes(id) on delete cascade,
  revision     int not null,
  storage_path text not null,            -- ej: quotes/<customer_id>/COT-1001-v1.pdf
  created_at   timestamptz not null default now(),
  unique (quote_id, revision)
);

-- Registro de envíos (correo automático o WhatsApp manual/automático)
create table public.quote_messages (
  id                  uuid primary key default gen_random_uuid(),
  quote_id            uuid not null references public.quotes(id) on delete cascade,
  document_id         uuid references public.quote_documents(id) on delete set null,
  channel             public.message_channel not null,
  recipient           text not null,                 -- correo o teléfono
  status              public.message_status not null default 'queued',
  provider_message_id text,
  error               text,
  sent_by             uuid references public.profiles(id) on delete set null,  -- null = automático
  created_at          timestamptz not null default now()
);
create index on public.quote_messages (quote_id);

-- ---------- 4. LA COTIZACIÓN ACEPTADA SE CONVIERTE EN PEDIDO ----------
alter table public.orders
  add column customer_id uuid references public.customers(id) on delete set null,
  add column quote_id    uuid unique references public.quotes(id) on delete set null;

create or replace function public.convert_quote_to_order(p_quote_id uuid)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  q public.quotes%rowtype;
  c public.customers%rowtype;
  v_order_id uuid;
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;

  select * into q from public.quotes
   where id = p_quote_id and status in ('requested', 'sent');
  if not found then
    raise exception 'La cotización no existe o ya no se puede aceptar';
  end if;
  if q.shipping_pending then
    raise exception 'Define el costo de envío antes de aceptar la cotización';
  end if;

  select * into c from public.customers where id = q.customer_id;

  insert into public.orders (
    user_id, customer_id, quote_id, email, phone,
    subtotal, shipping_cost, discount, total, currency,
    shipping_address, delivery_method, payment_method, delivery_zone_id,
    preferred_delivery_date, preferred_time_window, customer_notes
  ) values (
    c.profile_id, c.id, q.id, c.email, c.phone,
    q.subtotal, coalesce(q.shipping_cost, 0), q.discount, q.total, q.currency,
    coalesce(q.shipping_address, '{}'::jsonb), q.delivery_method, q.payment_method, q.delivery_zone_id,
    q.preferred_delivery_date, q.preferred_time_window, q.customer_notes
  ) returning id into v_order_id;

  insert into public.order_items (order_id, variant_id, product_name, variant_name, sku, unit_price, quantity)
  select v_order_id, variant_id, product_name, variant_name, sku, unit_price, quantity
    from public.quote_items where quote_id = q.id;

  update public.quotes set status = 'accepted', accepted_at = now() where id = q.id;

  return v_order_id;   -- el pedido queda "pending"; luego se usa confirm_order() para descontar stock
end $$;

-- Marca como vencidas las cotizaciones cuya vigencia ya pasó.
-- Llamar a diario desde un cron (pg_cron de Supabase o una tarea programada).
create or replace function public.expire_quotes()
returns int
language plpgsql security definer set search_path = '' as $$
declare n int;
begin
  update public.quotes set status = 'expired'
   where status in ('requested', 'sent') and valid_until < now();
  get diagnostics n = row_count;
  return n;
end $$;

revoke execute on function public.convert_quote_to_order(uuid) from public, anon;
revoke execute on function public.expire_quotes() from public, anon, authenticated;
grant  execute on function public.convert_quote_to_order(uuid) to authenticated;

-- ---------- 5. SEGURIDAD (RLS) ----------
-- Regla: el cliente con cuenta ve SOLO sus cotizaciones. El invitado entra con
-- el enlace con token, que el servidor valida con la service_role key.
-- Crear solicitudes y registrar envíos lo hace siempre el servidor.
create or replace function public.owns_quote(p_quote_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
      from public.quotes q
      join public.customers c on c.id = q.customer_id
     where q.id = p_quote_id and c.profile_id = auth.uid()
  );
$$;

alter table public.customers       enable row level security;
alter table public.quotes          enable row level security;
alter table public.quote_items     enable row level security;
alter table public.quote_documents enable row level security;
alter table public.quote_messages  enable row level security;

create policy "clientes: ver propio"  on public.customers for select using (profile_id = auth.uid() or public.is_admin());
create policy "clientes: admin"       on public.customers for all using (public.is_admin()) with check (public.is_admin());

create policy "cotizaciones: ver propias" on public.quotes for select using (public.owns_quote(id) or public.is_admin());
create policy "cotizaciones: admin"       on public.quotes for all using (public.is_admin()) with check (public.is_admin());

create policy "cot_items: ver propias" on public.quote_items for select using (public.owns_quote(quote_id) or public.is_admin());
create policy "cot_items: admin"       on public.quote_items for all using (public.is_admin()) with check (public.is_admin());

create policy "cot_pdf: ver propios" on public.quote_documents for select using (public.owns_quote(quote_id) or public.is_admin());
create policy "cot_pdf: admin"       on public.quote_documents for all using (public.is_admin()) with check (public.is_admin());

create policy "cot_envios: admin" on public.quote_messages for all using (public.is_admin()) with check (public.is_admin());

-- Los PDF viven en un bucket PRIVADO. Nunca se publican con URL abierta:
-- el servidor comprueba permiso (sesión, token o admin) y entrega un enlace
-- firmado de pocos minutos.
insert into storage.buckets (id, name, public)
values ('quotes', 'quotes', false)
on conflict (id) do nothing;
