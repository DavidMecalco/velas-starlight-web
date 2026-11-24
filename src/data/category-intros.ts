/**
 * Textos de cada categoría.
 * Editables:
 *  - `summary`: línea corta bajo el nombre en las tarjetas del inicio (mockup de inicio).
 *  - `intro`: párrafo visible bajo el título en /categoria/<slug>.
 *  - `description`: meta descripción para buscadores (unos 150 caracteres como máximo).
 * TEXTOS PROVISIONALES: revisar antes de publicar.
 */
export interface CategoryIntro {
  summary: string;
  intro: string;
  description: string;
}

export const categoryIntros: Record<string, CategoryIntro> = {
  velas: {
    summary: "De soya, de parafina y de figuras",
    intro: "Velas de soya y parafina hechas a mano, con aromas suaves y pensadas para durar.",
    description: "Velas artesanales de soya y parafina, hechas a mano en pequeños lotes, con aromas suaves y larga duración.",
  },
  belleza: {
    summary: "Jabones, cremas, shampoos y mascarillas",
    intro: "Jabones y aceites de ingredientes naturales para tu rutina diaria.",
    description: "Jabones artesanales y aceites faciales con ingredientes naturales, hechos en pequeños lotes.",
  },
  insumos: {
    summary: "Cera, aditivos, fragancias y mechas",
    intro: "Ceras, parafinas y materiales para que hagas tus propias velas.",
    description: "Parafina, cera de soya, mechas y materiales para hacer tus propias velas en casa o en tu taller.",
  },
  "moldes-3d": {
    summary: "Moldes impresos en 3D para tus velas",
    intro: "Moldes impresos en 3D para velas, jabones y yeso, listos para usar.",
    description: "Moldes impresos en 3D para velas, jabones y yeso, con diseños propios y listos para usar.",
  },
};

/** Texto para una categoría sin entrada en `categoryIntros`. */
export function getCategoryIntro(slug: string, name: string): CategoryIntro {
  return (
    categoryIntros[slug] ?? {
      summary: `Productos de ${name.toLowerCase()}`,
      intro: `Productos de ${name.toLowerCase()} hechos en pequeños lotes.`,
      description: `${name} de Velas Starlight: productos artesanales hechos en pequeños lotes.`,
    }
  );
}
