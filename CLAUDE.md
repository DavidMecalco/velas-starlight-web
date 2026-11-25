@AGENTS.md
# Velas Starlight: reglas del proyecto

Tienda en línea de velas artesanales, insumos (parafina, cera de soya, aditivos, fragancias), moldes impresos en 3D y productos de belleza natural. El MVP funciona por **cotización**: el cliente arma un carrito y solicita una cotización; se genera un PDF; la dueña la revisa, la envía y, si el cliente acepta, se convierte en pedido con **pago contra entrega**. Los pagos en línea llegan en una fase posterior.

## Stack

- **Astro** (TypeScript estricto) con endpoints de servidor en `src/pages/api/`
- **Supabase**: Postgres, autenticación con Google, Storage
- **CSS propio** con variables de diseño. No se usa Tailwind ni librerías de componentes.
- Node.js LTS. Gestor de paquetes: npm.

## Comandos

- `npm run dev`: servidor local en `localhost:4321`
- `npm run build`: compila para producción (debe pasar sin errores antes de cada commit)
- `npm run preview`: prueba la compilación

## Documentos de referencia (leer antes de trabajar)

| Archivo | Qué define |
|---|---|
| `docs/DESIGN_SYSTEM.md` | Colores, tipografía, espaciado, componentes y voz de marca |
| `docs/RUTAS.md` | Todas las páginas, endpoints, permisos y orden de construcción |
| `supabase/*.sql` | Esquema de la base de datos. Los archivos numerados son migraciones. |
| `src/styles/tokens.css` | Única fuente de valores de diseño |

Si algo no está en estos documentos, **se pregunta antes de inventarlo** y después se agrega al documento correspondiente.

## Reglas generales

1. **Idioma:** rutas y textos visibles en español (sin acentos en las URL). Código, variables, funciones y tablas en inglés.
2. **Pasos pequeños:** un cambio funcional por vez, probado, antes de pasar al siguiente. Seguir el orden de etapas de `RUTAS.md`.
3. **No instalar dependencias nuevas sin avisar** y explicar para qué se necesita.
4. **No tocar archivos fuera del alcance del rol activo** sin decirlo.
5. **Commits** pequeños, en español, con mensaje que diga qué cambió y por qué. Nunca subir `.env`.
6. Ante una instrucción ambigua, hacer **una** pregunta concreta en lugar de suponer.

## Reglas de seguridad (no negociables)

- `SUPABASE_SECRET_KEY` (service role) **solo en código de servidor** (`src/pages/api/`, `src/lib/server/`, middleware). Jamás en componentes del navegador ni con prefijo `PUBLIC_`.
- **Nunca confiar en precios, totales ni costos de envío que lleguen del navegador.** El servidor los recalcula desde la base de datos.
- Toda tabla nueva lleva **RLS activado** y políticas explícitas.
- Las rutas `/cuenta/*` y `/admin/*` se protegen en el servidor (middleware), no solo ocultando enlaces.
- Los PDF de cotización viven en un bucket **privado**; se entregan con enlace firmado temporal tras verificar permiso (sesión, token de la cotización o admin).
- No registrar en consola datos personales ni claves.

## Reglas de diseño

- Prohibido escribir colores hexadecimales, tamaños de letra o espacios "a mano" en componentes: se usan variables de `tokens.css` y las clases de `base.css` (`.btn`, `.badge`, `.field`, `.stack`, `.cluster`, `.container`, `.section`).
- Una sola acción primaria por vista. Máximo 2 insignias por producto, siempre monocromas.
- Cormorant Garamond solo por encima de 22 px; texto pequeño en DM Sans.
- Íconos: un solo set (Lucide), trazo de 1.5 px.
- Sin sombras en tarjetas; sin animaciones decorativas; respetar `prefers-reduced-motion`.
- Textos en minúsculas normales (sentence case), sin mayúsculas sostenidas.

## Roles

Cuando se invoque un rol ("Actúa como rol Datos"), trabajar solo dentro de su alcance.

### Rol 1: Diseño y UI
- **Alcance:** `src/styles/`, `src/components/`, `src/layouts/`, páginas `.astro` (solo la parte visual).
- **Hace:** layouts, encabezado y pie, tarjetas de producto, formularios, páginas, estados vacíos y de error, accesibilidad.
- **No hace:** consultas a la base de datos ni lógica de pedidos (las pide al rol Backend).
- **Terminado cuando:** usa solo tokens; se ve bien en 360, 768 y 1280 px; un solo `h1`; foco visible; contraste de texto de al menos 4.5:1; imágenes con `alt`, `width` y `height`.

### Rol 2: Datos (Supabase)
- **Alcance:** `supabase/`, `src/lib/supabase.ts`, tipos de la base de datos.
- **Hace:** migraciones nuevas, políticas RLS, funciones SQL, datos de prueba, cliente de Supabase (uno para navegador con clave pública y otro de servidor).
- **Reglas:** **nunca editar una migración ya ejecutada**; los cambios van en una nueva numerada (`migracion_03_...sql`). Probar siempre en el proyecto de pruebas.
- **Terminado cuando:** la migración corre limpia en un proyecto vacío, las políticas se probaron con usuario anónimo, cliente y admin.

### Rol 3: Backend
- **Alcance:** `src/pages/api/`, `src/middleware.ts`, `src/lib/` (carrito, envío, PDF, correo).
- **Hace:** endpoints, validación de entradas, creación de cotizaciones y pedidos, cálculo de envío por código postal, generación de PDF, envío de correos, protección de rutas.
- **Reglas:** validar toda entrada; devolver errores claros sin exponer detalles internos; operaciones de stock solo con las funciones SQL (`confirm_order`, `cancel_order`, `convert_quote_to_order`).
- **Terminado cuando:** el flujo funciona de punta a punta y se probaron los casos de error (stock insuficiente, código postal fuera de zona, cotización vencida, acceso sin permiso).

### Rol 4: QA
- **Alcance:** revisión; propone cambios, no refactoriza por su cuenta.
- **Hace:** recorrer los flujos como cliente y como administradora, revisar la lista de verificación de `DESIGN_SYSTEM.md` (sección 10), probar permisos, probar en móvil, revisar rendimiento y accesibilidad.
- **Entrega:** lista de hallazgos con pasos para reproducir, gravedad y archivo probable.

## Flujo de trabajo

1. Una rama por función (`etapa-1-catalogo`), nunca trabajar directo en `main`.
2. Pedir primero un plan breve; implementar; probar en `localhost:4321`; correr `npm run build`.
3. Commit, subir la rama y revisar antes de unir a `main`.

## Estado actual

- [x] Proyecto Astro creado, sistema de diseño conectado
- [x] Repositorio en GitHub
- [x] Proyecto de pruebas en Supabase con los tres archivos SQL ejecutados
- [ ] Hosting y adaptador de servidor (pendiente de elegir)
- [x] Etapa 1: layout base y catálogo con datos reales
- [x] Etapa 2: detalle de producto y páginas de categoría
- [x] Página de inicio
