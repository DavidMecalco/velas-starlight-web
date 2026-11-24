-- =====================================================================
-- MIGRACIÓN 01: pedidos con pago contra entrega (MVP)
-- Se ejecuta DESPUÉS de schema_velas_starlight.sql
-- Supabase > SQL Editor > New query
--
-- Estados del pedido (se reutiliza el enum existente order_status):
--   pending    = Recibido (el cliente lo levantó, falta confirmar)
--   processing = Confirmado y en preparación
--   shipped    = En camino
--   delivered  = Entregado y cobrado
--   cancelled  = Cancelado
--   (paid y refunded quedan reservados para la fase de pagos en línea)
-- =====================================================================

-- ---------- 1. TIPOS ----------
create type public.delivery_method as enum ('delivery', 'pickup');
create type public.payment_method  as enum ('cash', 'card_terminal', 'transfer');

-- ---------- 2. NUEVOS CAMPOS EN PEDIDOS ----------
alter table public.orders
  add column delivery_method       public.delivery_method not null default 'delivery',
  add column payment_method        public.payment_method  not null default 'cash',
  add column delivery_zone_id      uuid,                         -- se enlaza abajo
  add column preferred_delivery_date date,
  add column preferred_time_window text,                         -- 'manana' | 'tarde'
  add column cash_change_for       numeric(10,2) check (cash_change_for >= 0), -- "pagará con"
  add column confirmed_at          timestamptz,
  add column delivered_at          timestamptz,
  add column cancelled_reason      text,
  add column stock_deducted        boolean not null default false;

-- En contra entrega se confirma por teléfono o WhatsApp: el teléfono es obligatorio
alter table public.orders alter column phone set not null;

-- ---------- 3. ZONAS DE ENTREGA ----------
create table public.delivery_zones (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,                    -- "Zona centro", "Zona norte"
  postal_codes  text[] not null default '{}',     -- códigos postales que cubre
  fee           numeric(10,2) not null default 0 check (fee >= 0),
  min_order     numeric(10,2) not null default 0 check (min_order >= 0),
  estimated_days text,                            -- "1 a 2 días hábiles"
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);
create index on public.delivery_zones using gin (postal_codes);

alter table public.orders
  add constraint orders_delivery_zone_fk
  foreign key (delivery_zone_id) references public.delivery_zones(id) on delete set null;

alter table public.delivery_zones enable row level security;
create policy "zonas: lectura publica" on public.delivery_zones for select using (is_active or public.is_admin());
create policy "zonas: admin"           on public.delivery_zones for all using (public.is_admin()) with check (public.is_admin());

-- Ejemplo (ajusta nombre, códigos postales y tarifas a tu cobertura real):
-- insert into public.delivery_zones (name, postal_codes, fee, min_order, estimated_days)
-- values ('Zona 1', array['06000','06010','06020'], 60, 300, '1 a 2 días hábiles');

-- ---------- 4. CONFIRMAR PEDIDO (descuenta stock de forma atómica) ----------
-- El stock se descuenta al CONFIRMAR, no al recibir el pedido,
-- para que pedidos falsos o no confirmados no bloqueen inventario.
create or replace function public.confirm_order(p_order_id uuid)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  r record;
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;

  if not exists (
    select 1 from public.orders
    where id = p_order_id and status = 'pending' and stock_deducted = false
  ) then
    raise exception 'El pedido no existe o ya fue confirmado';
  end if;

  for r in
    select variant_id, quantity from public.order_items where order_id = p_order_id
  loop
    update public.product_variants
       set stock = stock - r.quantity
     where id = r.variant_id and stock >= r.quantity;

    if not found then
      -- Si falla una línea se revierte toda la función
      raise exception 'Stock insuficiente o producto no disponible (variante %)', r.variant_id;
    end if;
  end loop;

  update public.orders
     set status = 'processing', confirmed_at = now(), stock_deducted = true
   where id = p_order_id;
end $$;

-- ---------- 5. CANCELAR PEDIDO (devuelve stock si ya se había descontado) ----------
create or replace function public.cancel_order(p_order_id uuid, p_reason text default null)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  r record;
  v_deducted boolean;
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;

  select stock_deducted into v_deducted
    from public.orders
   where id = p_order_id and status in ('pending', 'processing', 'shipped');

  if not found then
    raise exception 'El pedido no existe o ya no se puede cancelar';
  end if;

  if v_deducted then
    for r in
      select variant_id, quantity from public.order_items where order_id = p_order_id
    loop
      update public.product_variants set stock = stock + r.quantity where id = r.variant_id;
    end loop;
  end if;

  update public.orders
     set status = 'cancelled', cancelled_reason = p_reason, stock_deducted = false
   where id = p_order_id;
end $$;

-- Solo usuarios con sesión pueden invocarlas (además validan is_admin() por dentro)
revoke execute on function public.confirm_order(uuid) from public, anon;
revoke execute on function public.cancel_order(uuid, text) from public, anon;
grant  execute on function public.confirm_order(uuid) to authenticated;
grant  execute on function public.cancel_order(uuid, text) to authenticated;

-- ---------- 6. NOTA SOBRE COBRO ----------
-- Al marcar un pedido como entregado, la aplicación debe hacer:
--   update orders set status='delivered', delivered_at=now(), paid_at=now() where id = ...;
-- así "paid_at" registra el momento del cobro contra entrega.
