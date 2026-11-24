-- =====================================================================
-- VELAS STARLIGHT: migración 04. Búsqueda sin acentos en el catálogo
-- Agrega a catalog_products la columna search_text: nombre y descripción
-- corta en minúsculas y sin acentos. Así "jabon", "Jabón" y "JABON"
-- encuentran el mismo producto.
-- Requiere migracion_03_catalogo.sql.
-- =====================================================================

-- 1. Extensión unaccent en el esquema "extensions" (convención de Supabase)
create extension if not exists unaccent with schema extensions;

-- La vista usa security_invoker: quien consulta (anon, authenticated)
-- necesita poder usar el esquema y ejecutar la función.
grant usage on schema extensions to anon, authenticated;
grant execute on function extensions.unaccent(text) to anon, authenticated;

-- 2. Misma vista que en la migración 03, con search_text AL FINAL.
-- create or replace view solo permite agregar columnas al final, sin
-- cambiar nombre, tipo ni orden de las existentes.
create or replace view public.catalog_products
with (security_invoker = true) as
select
  p.id,
  p.slug,
  p.name,
  p.short_description,
  p.kind,
  p.category_id,
  c.slug          as category_slug,
  p.is_new,
  p.is_bestseller,
  p.is_featured,
  p.created_at,
  cheapest.price             as min_price,
  cheapest.compare_at_price  as compare_at_price,
  stock.in_stock,
  img.url         as image_url,
  img.alt         as image_alt,
  lower(extensions.unaccent(
    coalesce(p.name, '') || ' ' || coalesce(p.short_description, '')
  ))              as search_text
from public.products p
left join public.categories c on c.id = p.category_id
join lateral (
  select v.price, v.compare_at_price
  from public.product_variants v
  where v.product_id = p.id and v.is_active
  order by v.price asc, v.sort_order asc
  limit 1
) cheapest on true
join lateral (
  select bool_or(v.stock > 0) as in_stock
  from public.product_variants v
  where v.product_id = p.id and v.is_active
) stock on true
left join lateral (
  select i.url, i.alt
  from public.product_images i
  where i.product_id = p.id
  order by i.sort_order asc
  limit 1
) img on true
where p.is_active;

-- Los permisos de la vista se conservan con create or replace;
-- se repiten por claridad.
grant select on public.catalog_products to anon, authenticated;

-- Comprobación (debe devolver {security_invoker=true}):
-- select reloptions from pg_class where oid = 'public.catalog_products'::regclass;
