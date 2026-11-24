import {
  listCategories,
  listProducts,
  parsePage,
  parseSort,
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
