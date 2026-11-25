import {
  listCategories,
  listProducts,
  parsePage,
  parseSort,
  type CatalogProduct,
  type CategoryWithCount,
  type ProductPage,
  type SortOption,
} from "../lib/products";

/** Estado del listado, leído de la URL. */
export interface CatalogState {
  /** Slug de la categoría ("" = todas). */
  categoria: string;
  q: string;
  orden: SortOption;
  pagina: number;
}

export interface CatalogData {
  result: ProductPage | null;
  categories: CategoryWithCount[];
  failed: boolean;
}

export const SORT_LABELS: Record<SortOption, string> = {
  recientes: "Más recientes",
  "precio-asc": "Precio: menor a mayor",
  "precio-desc": "Precio: mayor a menor",
  nombre: "Nombre (A-Z)",
};

/**
 * Lee el estado del listado. En /categoria/<slug> la categoría viene de la
 * ruta (`categoryFromPath`); en /productos, del parámetro ?categoria=.
 */
export function readCatalogParams(url: URL, categoryFromPath?: string): CatalogState {
  const params = url.searchParams;
  return {
    categoria: categoryFromPath ?? params.get("categoria") ?? "",
    q: params.get("q") ?? "",
    orden: parseSort(params.get("orden")),
    pagina: parsePage(params.get("pagina")),
  };
}

/** Carga productos y categorías a la vez. Si algo falla, `failed` es true. */
export async function loadCatalog(state: CatalogState): Promise<CatalogData> {
  try {
    const [result, categories] = await Promise.all([
      listProducts({ category: state.categoria, q: state.q, sort: state.orden, page: state.pagina }),
      listCategories(),
    ]);
    return { result, categories, failed: false };
  } catch {
    return { result: null, categories: [], failed: true };
  }
}

/**
 * Elige los favoritos del inicio: hasta `limit` destacados y, si faltan,
 * completa con los más recientes que no estén ya incluidos.
 */
export async function chooseFavorites(
  featured: CatalogProduct[],
  loadRecent: (count: number) => Promise<CatalogProduct[]>,
  limit = 4,
): Promise<CatalogProduct[]> {
  const picked = featured.slice(0, limit);
  if (picked.length >= limit) return picked;

  // Se piden de más para poder descartar los que ya están como destacados.
  const seen = new Set(picked.map((p) => p.id));
  for (const product of await loadRecent(limit + picked.length)) {
    if (picked.length >= limit) break;
    if (!seen.has(product.id)) {
      picked.push(product);
      seen.add(product.id);
    }
  }
  return picked;
}

/**
 * Favoritos del inicio: siempre `limit` tarjetas (si hay suficientes productos).
 * Primero los destacados y, si faltan, se completa con los más recientes sin repetir.
 * Si la base de datos falla, devuelve [].
 */
export async function loadFavorites(limit = 4): Promise<CatalogProduct[]> {
  try {
    const { items } = await listProducts({ featured: true, limit });
    return await chooseFavorites(items, async (count) => (await listProducts({ limit: count })).items, limit);
  } catch {
    return [];
  }
}

/**
 * Ruta base del listado: /categoria/<slug> si la categoría existe;
 * si no, /productos (con ?categoria= en los parámetros).
 */
export function catalogBasePath(categoria: string, knownSlugs: Set<string>): string {
  return categoria && knownSlugs.has(categoria) ? `/categoria/${encodeURIComponent(categoria)}` : "/productos";
}

/**
 * Arma una URL del listado conservando el estado actual.
 * Omite los valores por defecto y vuelve a la página 1 si cambia un filtro.
 */
export function buildCatalogUrl(
  state: CatalogState,
  changes: Partial<CatalogState>,
  knownSlugs: Set<string>,
): string {
  const next: CatalogState = { ...state, ...changes };
  if (!("pagina" in changes)) next.pagina = 1;

  const base = catalogBasePath(next.categoria, knownSlugs);
  const url = new URLSearchParams();
  if (next.categoria && base === "/productos") url.set("categoria", next.categoria);
  if (next.q) url.set("q", next.q);
  if (next.orden !== "recientes") url.set("orden", next.orden);
  if (next.pagina > 1) url.set("pagina", String(next.pagina));
  const qs = url.toString();
  return qs ? `${base}?${qs}` : base;
}
