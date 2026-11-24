# Sistema de diseño: Velas Starlight

Documento de referencia para diseño y desarrollo. Si algo no está aquí, se decide primero y luego se agrega aquí. Los valores reales viven en `tokens.css`; este documento explica cómo usarlos.

## 1. Concepto

**Elegante, moderno, minimalista.** La marca es artesanal y natural, así que el diseño se apoya en tres ideas:

1. **Mucho aire.** Espacios generosos, pocos elementos por pantalla.
2. **El producto es el protagonista.** Las fotos hacen el trabajo; la interfaz se mantiene callada.
3. **Un solo detalle memorable.** El contraste entre el serif elegante de los títulos y la sans limpia del texto. Todo lo demás es discreto.

**Qué cambia respecto al diseño actual**

| Hoy | Nuevo | Motivo |
|---|---|---|
| 3 familias tipográficas (Playfair, Poppins, Inter) | 2 familias (Cormorant Garamond + DM Sans) | Coherencia entre páginas |
| Íconos azul, rosa y verde brillante en Contacto | Íconos de un solo trazo en verde pino | Paleta de marca unificada |
| Etiquetas rojas y amarillas (Bestseller, Destacado) | Insignias monocromas en tonos de verde | Menos ruido visual |
| Botones tipo píldora, tarjetas con sombra | Botones con esquina suave (6 px), productos sin caja ni sombra | Más sobrio y premium |
| Etiquetas en MAYÚSCULAS con espaciado | Texto en minúsculas normales (sentence case) | Más moderno y legible |
| Fondo con degradados | Fondos planos marfil y salvia | Minimalismo |

## 2. Color

### Paleta base

| Nombre | Hex | Uso |
|---|---|---|
| Pino 900 | `#1F3A2D` | Títulos |
| **Pino 700** | `#2F5D45` | **Color primario**: botones, enlaces, logo |
| Pino 600 | `#3B7054` | Hover del primario |
| Salvia 500 | `#8A9A86` | Bordes al pasar el cursor, detalles |
| Salvia 300 | `#C5CDBF` | Bordes y divisores |
| Salvia 100 | `#E6EAE1` | Superficies suaves, insignias |
| Marfil 50 | `#FAFAF7` | **Fondo principal** |
| Marfil 100 | `#F3F4EF` | Fondo de secciones alternas |
| Tinta 900 | `#1B211D` | Texto principal |
| Tinta 600 | `#4C5650` | Texto secundario |
| Tinta 500 | `#66706A` | Texto atenuado (el más claro permitido para texto) |
| Latón 700 | `#7D5F2E` | Acento en texto (precio rebajado, un detalle) |
| Latón 500 | `#A8844A` | Acento solo decorativo (líneas, íconos grandes) |

Estados: éxito `#2F7D4F`, error `#A83A32`, aviso `#8A5A10`, info `#2F5F7A`.

### Reglas de uso

- **Proporción aproximada:** 70 % marfil y blanco, 20 % pino y tinta, 8 % salvia, 2 % latón.
- En los componentes se usan los **tokens semánticos** (`--color-primary`, `--color-text`...), nunca los hex ni los nombres de la paleta directamente.
- El latón es el "toque de llama": máximo un elemento por pantalla.
- No usar rojo ni amarillo brillantes fuera de los estados de error y aviso.
- No usar el blanco puro como fondo de página; el blanco se reserva para tarjetas de formulario y superficies elevadas.

### Contraste (WCAG)

Combinaciones calculadas para cumplir al menos 4.5:1 en texto normal:

| Texto | Fondo | Contraste aprox. |
|---|---|---|
| Tinta 900 | Marfil 50 | más de 14:1 |
| Tinta 600 | Marfil 50 | 7.3:1 |
| Tinta 500 | Marfil 50 | 4.9:1 |
| Blanco | Pino 700 | 7.6:1 |
| Latón 700 | Marfil 50 | 5.7:1 |

Latón 500 (3.3:1) y Salvia 500 **no** se usan para texto. Verificar con una herramienta antes de lanzar.

## 3. Tipografía

| Rol | Fuente | Dónde |
|---|---|---|
| Display | **Cormorant Garamond** (500, 600) | Títulos h1 a h3, nombres de producto grandes |
| Cuerpo e interfaz | **DM Sans** (variable, 400 a 600) | Párrafos, menús, botones, precios, formularios |

Cormorant es muy fina: **no usarla por debajo de 22 px**. Para todo texto pequeño, DM Sans.

### Escala (fluida, se adapta sola entre móvil y escritorio)

| Token | Móvil | Escritorio | Interlineado | Uso |
|---|---|---|---|---|
| `--text-h1` | 44 px | 80 px | 1.02 | Título principal del inicio, una vez por página |
| `--text-h2` | 34 px | 52 px | 1.08 | Título de sección |
| `--text-h3` | 26 px | 34 px | 1.15 | Subtítulos, nombre de producto en detalle |
| `--text-h4` | 20 px | 24 px | 1.25 | Encabezados pequeños (DM Sans medium) |
| `--text-lead` | 18 px | 20 px | 1.65 | Párrafo de introducción |
| `--text-base` | 16 px | 16 px | 1.65 | Texto normal |
| `--text-sm` | 14 px | 14 px | 1.4 | Datos secundarios, ayudas |
| `--text-xs` | 13 px | 13 px | 1.4 | Insignias, avisos legales |
| `--text-card` | 22 px | 24 px | 1.15 | Nombre de producto en tarjeta (Cormorant) |

`--tracking-logo` (0.3em) se usa **solo** en el logotipo "VELAS / STARLIGHT"; es la única excepción a la regla de no usar mayúsculas espaciadas.

Reglas:
- Ancho máximo de párrafo: **62 caracteres** (`--measure`).
- Títulos con interletrado ligeramente negativo (`-0.012em`); texto normal sin ajuste.
- Evitar mayúsculas sostenidas con espaciado amplio y evitar resaltar una sola palabra del título con otro color o cursiva.
- Precios siempre con cifras tabulares (`.price`). Rebaja: precio actual con `.price--sale` (latón) y anterior tachado con `.price--compare`.
- Un solo `h1` por página. No saltarse niveles.
- Alineación: títulos y texto **a la izquierda** por defecto; centrar solo el hero y los encabezados de sección cortos.

### Instalación de fuentes (autoalojadas, más rápido y sin depender de Google)

```bash
npm i @fontsource-variable/dm-sans @fontsource/cormorant-garamond
```

```js
// en el layout principal
import "@fontsource-variable/dm-sans";
import "@fontsource/cormorant-garamond/500.css";
import "@fontsource/cormorant-garamond/600.css";
```

## 4. Espaciado y layout

- **Base de 4 px.** Escala: 4, 8, 12, 16, 24, 32, 48, 64, 96, 128 (`--space-1` a `--space-10`).
- **Contenedor:** 1200 px máximo; 736 px para textos y formularios.
- **Espacio entre secciones:** `--section-y` (64 px en móvil, hasta 128 px en escritorio).
- **Breakpoints:** 640, 768, 1024 y 1280 px. Diseñar primero para móvil.
- **Rejilla de productos:** 2 columnas en móvil, 3 desde 768 px, 4 desde 1280 px.

## 5. Forma y elevación

| Elemento | Radio |
|---|---|
| Insignias | 4 px |
| Botones y campos de formulario | 6 px |
| Fotos de producto | 4 px |
| Cajón del carrito, modales | 12 px |
| Avatares | circular |

- **Sin sombras** en tarjetas de producto ni secciones. Solo sombra suave (`--shadow-float`) en lo que flota: carrito lateral, menús desplegables, avisos.
- Bordes de 1 px en Salvia 300.

## 6. Imágenes e íconos

- **Fotos de producto:** proporción **4:5** (vertical), fondo neutro y luz natural. Misma proporción en todo el catálogo; la consistencia importa más que la calidad individual.
- **Formatos:** WebP o AVIF, con `width` y `height` definidos para evitar saltos de página. Usar el componente de imagen de Astro.
- **Íconos:** un solo set, **Lucide**, trazo de 1.5 px, color heredado del texto. Sin íconos de colores ni en cajas de color.

## 7. Componentes base

| Componente | Reglas |
|---|---|
| **Botón primario** | Fondo Pino 700, texto blanco, alto 48 px. Una sola acción primaria por vista ("Agregar al carrito", "Pagar"). |
| **Botón secundario** | Contorno Pino 700, fondo transparente. |
| **Enlace** | Pino 700, subrayado fino al pasar el cursor. |
| **Insignia** | Máximo 2 por producto. "Nuevo" (salvia suave), "Más vendido" (pino sólido), "Agotado" (gris suave). Se elimina "Destacado" como etiqueta: destacar es decisión de ubicación, no de etiqueta. |
| **Tarjeta de producto** | Foto 4:5, debajo nombre (Cormorant 22 a 24 px), precio (DM Sans). Sin caja ni sombra. |
| **Campos** | Alto 48 px, etiqueta visible arriba (nunca solo placeholder), error en texto debajo, no solo en color. |
| **Aviso (toast)** | Esquina superior derecha, sombra flotante, se cierra solo a los 5 s y tiene botón de cerrar. |

## 8. Movimiento

- Duraciones: 150 ms (cambios de color), 250 ms (apertura de menús), 400 ms (cajón del carrito).
- Curva: `--ease-out`.
- **Solo movimiento que responde a una acción** (abrir carrito, agregar producto, expandir). Nada de entradas animadas en cada sección ni efectos al pasar sobre cada tarjeta.
- Se respeta `prefers-reduced-motion` (ya incluido en `base.css`).

## 9. Voz y textos

- Sentence case: "Agregar al carrito", no "AGREGAR AL CARRITO".
- Botones con el verbo exacto de lo que ocurre: "Agregar al carrito", "Pagar", "Enviar solicitud".
- Mismo nombre para la misma acción en todo el flujo (si el botón dice "Agregar al carrito", el aviso dice "Agregado al carrito").
- Errores: dicen qué pasó y cómo arreglarlo, sin disculpas ni dramatismo.
- Cifras como "500+ clientes" o "100 % satisfacción" solo si son reales y comprobables.

## 10. Lista de verificación antes de publicar una pantalla

- [ ] Solo usa variables de `tokens.css` (cero hex o px sueltos para color, tamaño de texto o espacios).
- [ ] Se ve bien en 360, 768 y 1280 px de ancho.
- [ ] Un solo `h1`, jerarquía de títulos ordenada.
- [ ] Contraste de texto mínimo 4.5:1.
- [ ] Todo se puede usar con teclado y el foco se ve.
- [ ] Imágenes con `alt`, `width` y `height`.
- [ ] Funciona con "reducir movimiento" activado.
- [ ] Lighthouse: rendimiento y accesibilidad por encima de 90.

## 11. Estructura de archivos

```
src/
  styles/
    tokens.css      <- variables (única fuente de verdad)
    base.css        <- reset, tipografía, layout, botones, campos
  components/       <- componentes Astro que SOLO usan tokens
  layouts/
    Base.astro      <- importa fuentes, tokens.css y base.css
DESIGN_SYSTEM.md    <- este documento
```
