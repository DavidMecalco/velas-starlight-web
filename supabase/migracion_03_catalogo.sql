-- =====================================================================
-- VELAS STARLIGHT: migración 03. Vista del catálogo
-- Precalcula por producto: precio mínimo, precio tachado de esa variante,
-- si hay stock e imagen principal. Así Postgres puede filtrar, ordenar
-- por precio y paginar.
-- security_invoker = true: la vista aplica el RLS de quien consulta
-- (el anónimo solo ve productos y variantes activos).
-- =====================================================================

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
  img.alt         as image_alt
from public.products p
left join public.categories c on c.id = p.category_id
-- Variante activa más barata (su precio tachado va con ella)
join lateral (
  select v.price, v.compare_at_price
  from public.product_variants v
  where v.product_id = p.id and v.is_active
  order by v.price asc, v.sort_order asc
  limit 1
) cheapest on true
-- ¿Alguna variante activa con stock?
join lateral (
  select bool_or(v.stock > 0) as in_stock
  from public.product_variants v
  where v.product_id = p.id and v.is_active
) stock on true
-- Imagen principal: la primera por sort_order
left join lateral (
  select i.url, i.alt
  from public.product_images i
  where i.product_id = p.id
  order by i.sort_order asc
  limit 1
) img on true
where p.is_active;

grant select on public.catalog_products to anon, authenticated;
