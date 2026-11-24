/**
 * Textos de cada categoría para /categoria/<slug>.
 * Editables: `intro` es el párrafo visible bajo el título y `description`
 * la meta descripción para buscadores (unos 150 caracteres como máximo).
 * TEXTOS PROVISIONALES: revisar antes de publicar.
 */
export interface CategoryIntro {
  intro: string;
  description: string;
}

export const categoryIntros: Record<string, CategoryIntro> = {
  velas: {
    intro: "Velas de soya y parafina hechas a mano, con aromas suaves y pensadas para durar.",
    description: "Velas artesanales de soya y parafina, hechas a mano en pequeños lotes, con aromas suaves y larga duración.",
  },
  belleza: {
    intro: "Jabones y aceites de ingredientes naturales para tu rutina diaria.",
    description: "Jabones artesanales y aceites faciales con ingredientes naturales, hechos en pequeños lotes.",
  },
  insumos: {
    intro: "Ceras, parafinas y materiales para que hagas tus propias velas.",
    description: "Parafina, cera de soya, mechas y materiales para hacer tus propias velas en casa o en tu taller.",
  },
  "moldes-3d": {
    intro: "Moldes impresos en 3D para velas, jabones y yeso, listos para usar.",
    description: "Moldes impresos en 3D para velas, jabones y yeso, con diseños propios y listos para usar.",
  },
};

/** Texto para una categoría sin entrada en `categoryIntros`. */
export function getCategoryIntro(slug: string, name: string): CategoryIntro {
  return (
    categoryIntros[slug] ?? {
      intro: `Productos de ${name.toLowerCase()} hechos en pequeños lotes.`,
      description: `${name} de Velas Starlight: productos artesanales hechos en pequeños lotes.`,
    }
  );
}
