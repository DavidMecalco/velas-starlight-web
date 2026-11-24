-- =====================================================================
-- VELAS STARLIGHT: datos de prueba para el detalle de producto
-- SOLO PRUEBAS. Ejecutar únicamente en el proyecto de pruebas. No es una migración.
-- Requiere schema_velas_starlight.sql y las migraciones 01 a 04.
--
-- Agrega:
--   1. Escalón de mayoreo para VSL-LAV-200: desde 6 piezas a $190.
--   2. Rebaja en VSL-LAV-350: precio tachado $360 (precio actual $320).
--   3. Producto INACTIVO con una variante activa      (demo-vela-inactiva).
--   4. Producto activo SIN variantes activas            (demo-sin-variantes).
-- Los productos 3 y 4 llevan attributes {"demo":"true"}.
-- 1 y 2 no se pueden marcar (sus tablas no tienen attributes);
-- se deshacen por SKU (ver el final del archivo).
--
-- CUIDADO: los 8 productos de ejemplo del catálogo TAMBIÉN tienen
-- {"demo":"true"}. Para deshacer este seed se borra por slug, nunca con
-- "where attributes->>'demo' = 'true'", porque eso vaciaría el catálogo.
--
-- Se puede ejecutar más de una vez sin duplicar datos.
-- =====================================================================

begin;

-- 1. Escalón de mayoreo
insert into public.wholesale_tiers (variant_id, min_qty, unit_price)
select v.id, 6, 190.00
from public.product_variants v
where v.sku = 'VSL-LAV-200'
on conflict (variant_id, min_qty) do update set unit_price = excluded.unit_price;

-- 2. Rebaja (antes de esto, compare_at_price es null)
update public.product_variants
set compare_at_price = 360.00
where sku = 'VSL-LAV-350';

-- 3. Producto inactivo: su variante sí está activa, para que lo único
--    que lo oculte sea products.is_active = false.
insert into public.products (slug, name, short_description, kind, category_id, is_active, attributes)
select 'demo-vela-inactiva', 'Vela demo inactiva', 'Producto de prueba: no debe verse.',
       'vela', c.id, false, '{"demo":"true"}'::jsonb
from public.categories c
where c.slug = 'velas'
on conflict (slug) do nothing;

insert into public.product_variants (product_id, sku, name, options, price, stock, weight_grams, is_active)
select p.id, 'DEMO-INACT-1', '200 g', '{"tamano":"200 g"}'::jsonb, 150.00, 5, 450, true
from public.products p
where p.slug = 'demo-vela-inactiva'
on conflict (sku) do nothing;

-- 4. Producto activo cuya única variante está inactiva:
--    no debe aparecer en el catálogo ni abrirse en el detalle.
insert into public.products (slug, name, short_description, kind, category_id, is_active, attributes)
select 'demo-sin-variantes', 'Vela demo sin variantes', 'Producto de prueba: no debe verse.',
       'vela', c.id, true, '{"demo":"true"}'::jsonb
from public.categories c
where c.slug = 'velas'
on conflict (slug) do nothing;

insert into public.product_variants (product_id, sku, name, options, price, stock, weight_grams, is_active)
select p.id, 'DEMO-SINVAR-1', '200 g', '{"tamano":"200 g"}'::jsonb, 150.00, 5, 450, false
from public.products p
where p.slug = 'demo-sin-variantes'
on conflict (sku) do nothing;

commit;

-- Comprobación rápida (opcional):
-- select sku, price, compare_at_price from public.product_variants where sku in ('VSL-LAV-200','VSL-LAV-350');
-- select v.sku, t.min_qty, t.unit_price from public.wholesale_tiers t join public.product_variants v on v.id = t.variant_id;
-- select slug, is_active from public.products where slug in ('demo-vela-inactiva', 'demo-sin-variantes');
-- select count(*) from public.catalog_products;   -- debe seguir en 8

-- =====================================================================
-- DESHACER (descomentar y ejecutar para quitar todo lo anterior)
-- =====================================================================
-- begin;
-- -- 3 y 4: borra SOLO estos dos productos (por slug); sus variantes se borran en cascada
-- delete from public.products where slug in ('demo-vela-inactiva', 'demo-sin-variantes');
-- -- 2: quita la rebaja
-- update public.product_variants set compare_at_price = null where sku = 'VSL-LAV-350';
-- -- 1: quita el escalón de mayoreo
-- delete from public.wholesale_tiers t
-- using public.product_variants v
-- where t.variant_id = v.id and v.sku = 'VSL-LAV-200' and t.min_qty = 6;
-- commit;
