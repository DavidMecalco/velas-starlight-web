import { supabase } from './supabase';

/** Productos por página en el catálogo. */
export const PAGE_SIZE = 12;

export type ProductKind = 'vela' | 'belleza' | 'insumo' | 'molde';

/** Fila de la vista public.catalog_products (migracion_03_catalogo.sql). */
export interface CatalogProduct {
  id: string;
  slug: string;
  name: string;
  short_description: string | null;
  kind: ProductKind;
  category_id: string | null;
  category_slug: string | null;
  is_new: boolean;
  is_bestseller: boolean;
  is_featured: boolean;
  created_at: string;
  /** numeric llega como número o texto según el driver; se normaliza a number. */
  min_price: number;
  compare_at_price: number | null;
  in_stock: boolean;
  image_url: string | null;
  image_alt: string | null;
}

export interface CategoryWithCount {
  id: string;
  slug: string;
  name: string;
  kind: ProductKind;
  product_count: number;
}

/** Valores de `?orden=` aceptados. */
export const SORT_OPTIONS = ['recientes', 'precio-asc', 'precio-desc', 'nombre'] as const;
export type SortOption = (typeof SORT_OPTIONS)[number];
const DEFAULT_SORT: SortOption = 'recientes';

export interface ListProductsParams {
  /** Slug de la categoría (`velas`, `moldes-3d`...). */
  category?: string | null;
  /** Texto de búsqueda (`?q=`). */
  q?: string | null;
  /** Orden (`?orden=`). Valores desconocidos usan el orden por defecto. */
  sort?: string | null;
  /** Página (`?pagina=`), empieza en 1. */
  page?: string | number | null;
}

export interface ProductPage {
  items: CatalogProduct[];
  total: number;
  page: number;
  totalPages: number;
  pageSize: number;
  sort: SortOption;
  q: string;
}

const CATALOG_COLUMNS =
  'id, slug, name, short_description, kind, category_id, category_slug, is_new, is_bestseller, is_featured, created_at, min_price, compare_at_price, in_stock, image_url, image_alt';

/** Error genérico para la interfaz; no expone detalles internos de la base de datos. */
class CatalogError extends Error {
  constructor() {
    super('No se pudo cargar el catálogo.');
    this.name = 'CatalogError';
  }
}

export function parseSort(value: string | null | undefined): SortOption {
  return SORT_OPTIONS.includes(value as SortOption) ? (value as SortOption) : DEFAULT_SORT;
}

export function parsePage(value: string | number | null | undefined): number {
  const n = typeof value === 'number' ? value : Number.parseInt(value ?? '', 10);
  return Number.isInteger(n) && n >= 1 ? n : 1;
}

/**
 * Limpia el texto de búsqueda: recorta y quita los caracteres que tienen
 * significado en los filtros de PostgREST (comodines, comas, paréntesis, comillas).
 */
export function sanitizeQuery(value: string | null | undefined): string {
  return (value ?? '')
    .slice(0, 80)
    .replace(/[%_*,.()"'\\:]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Prepara el texto para compararlo con la columna search_text de la vista
 * (que usa lower + unaccent): minúsculas y sin acentos ("Jabón" → "jabon").
 */
export function toSearchText(value: string): string {
  return value.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
}

function normalize(row: CatalogProduct): CatalogProduct {
  return {
    ...row,
    min_price: Number(row.min_price),
    compare_at_price: row.compare_at_price == null ? null : Number(row.compare_at_price),
  };
}

/** Lista los productos activos con filtros, búsqueda, orden y paginación de 12 en 12. */
export async function listProducts(params: ListProductsParams = {}): Promise<ProductPage> {
  const sort = parseSort(params.sort);
  const page = parsePage(params.page);
  // q: limpio pero con acentos, para mostrarlo en el buscador.
  // searchText: además en minúsculas y sin acentos, para filtrar.
  const q = sanitizeQuery(params.q);
  const searchText = toSearchText(q);
  const from = (page - 1) * PAGE_SIZE;
  const to = from + PAGE_SIZE - 1;

  // Construye la consulta con los filtros comunes (para la página y para el conteo).
  const filtered = (columns: string, head = false) => {
    let base = supabase.from('catalog_products').select(columns, { count: 'exact', head });
    if (params.category) base = base.eq('category_slug', params.category);
    if (searchText) base = base.like('search_text', `%${searchText}%`);
    return base;
  };

  let query = filtered(CATALOG_COLUMNS);

  switch (sort) {
    case 'precio-asc':
      query = query.order('min_price', { ascending: true });
      break;
    case 'precio-desc':
      query = query.order('min_price', { ascending: false });
      break;
    case 'nombre':
      query = query.order('name', { ascending: true });
      break;
    default:
      query = query.order('created_at', { ascending: false });
  }
  // Desempate estable para que la paginación no repita ni salte productos.
  query = query.order('id', { ascending: true }).range(from, to);

  const { data, count, error } = await query;

  // Página fuera de rango: PostgREST responde 416 sin conteo. Se devuelve lista
  // vacía con el total real para que la interfaz pueda ofrecer volver a la página 1.
  if (error && error.code === 'PGRST103') {
    const { count: realTotal, error: countError } = await filtered('id', true);
    if (countError) throw new CatalogError();
    const total = realTotal ?? 0;
    return { items: [], total, page, totalPages: Math.ceil(total / PAGE_SIZE), pageSize: PAGE_SIZE, sort, q };
  }
  if (error) throw new CatalogError();

  const total = count ?? 0;
  return {
    // Sin tipos generados de la BD, la fila se tipa con la interfaz escrita a mano.
    items: (data as unknown as CatalogProduct[]).map(normalize),
    total,
    page,
    totalPages: Math.ceil(total / PAGE_SIZE),
    pageSize: PAGE_SIZE,
    sort,
    q,
  };
}

/** Lista las categorías con el número de productos visibles en cada una. */
export async function listCategories(): Promise<CategoryWithCount[]> {
  const [categories, products] = await Promise.all([
    supabase.from('categories').select('id, slug, name, kind').order('sort_order', { ascending: true }),
    supabase.from('catalog_products').select('category_id'),
  ]);

  if (categories.error || products.error) throw new CatalogError();

  const counts = new Map<string, number>();
  for (const { category_id } of products.data) {
    if (category_id) counts.set(category_id, (counts.get(category_id) ?? 0) + 1);
  }

  return categories.data.map((c) => ({
    id: c.id,
    slug: c.slug,
    name: c.name,
    kind: c.kind as ProductKind,
    product_count: counts.get(c.id) ?? 0,
  }));
}
