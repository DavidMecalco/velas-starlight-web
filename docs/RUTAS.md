# Directorio de páginas y rutas: Velas Starlight

Documento de referencia de la arquitectura del sitio. Define qué páginas existen, su URL, quién puede verlas, cómo se generan y de dónde salen sus datos. Cualquier página nueva se agrega aquí antes de programarse.

## 1. Convenciones

| Tema | Regla |
|---|---|
| Idioma de las URL | Español, en minúsculas, sin acentos ni eñes, palabras separadas por guion (`/moldes-3d`). |
| Idioma del código | Inglés para variables, funciones y tablas; español solo en rutas y textos visibles. |
| Slugs | Únicos, estables y generados desde el nombre (`vela-de-cedro`). Si el producto cambia de nombre, el slug no cambia. |
| Filtros del catálogo | Por parámetros de URL (`?q=`, `?orden=`, `?pagina=`) para que se puedan compartir y recargar. |
| Archivos | En Astro la ruta es el archivo: `src/pages/productos/[slug].astro` responde en `/productos/vela-de-cedro`. |
| Renderizado | **Estática**: se genera una vez (`prerender = true`). **Servidor (SSR)**: se genera en cada visita con datos actuales. |

**Niveles de acceso:** `Público` (cualquiera), `Cliente` (sesión iniciada), `Admin` (rol `admin` en `profiles`). El acceso se verifica en el servidor mediante `middleware.ts`, nunca solo ocultando enlaces.

## 2. Mapa del sitio

```
/                                   Inicio
├── productos                       Catálogo completo
│   └── [slug]                      Detalle de producto
├── categoria/[slug]                Catálogo filtrado (velas, belleza, insumos, moldes-3d)
├── carrito                         Carrito
├── checkout                        Datos de envío y pago
│   └── confirmacion/[pedido]       Pedido recibido
├── contacto                        Contacto general
├── eventos-y-mayoreo               Cotizaciones (eventos, bodas, mayoreo)
├── nosotros                        Historia de la marca
├── envios | devoluciones | faq     Ayuda
├── privacidad | terminos           Legales
├── iniciar-sesion                  Acceso con Google
├── cuenta/                         Área del cliente
│   ├── pedidos  └── [numero]
│   ├── direcciones
│   └── perfil
└── admin/                          Panel de administración
    ├── productos  ├── nuevo  └── [id]
    ├── pedidos    └── [numero]
    ├── cotizaciones
    └── resenas
```

## 3. Páginas públicas

| Ruta | Archivo (`src/pages/`) | Propósito | Render | Datos (tablas) | Etapa |
|---|---|---|---|---|---|
| `/` | `index.astro` | Presentar la marca, productos destacados y accesos a categorías | Estática (se reconstruye al cambiar destacados) o SSR con caché | `products` (`is_featured`), `categories` | 1 |
| `/productos` | `productos/index.astro` | Catálogo completo con filtros, búsqueda, orden y paginación | SSR | `products`, `product_variants`, `product_images`, `categories` | 1 |
| `/productos/[slug]` | `productos/[slug].astro` | Detalle: galería, variantes (aroma, tamaño), precio, stock, mayoreo, reseñas, botón de agregar | SSR | `products`, `product_variants`, `product_images`, `wholesale_tiers`, `reviews` | 2 |
| `/categoria/[slug]` | `categoria/[slug].astro` | Catálogo de una categoría con su propia URL e introducción (SEO) | SSR | `categories`, `products` | 2 |
| `/carrito` | `carrito.astro` | Revisar productos, cantidades y subtotal. Convive con el cajón lateral del encabezado | SSR (valida precios y stock) | `product_variants` | 3 |
| `/checkout` | `checkout.astro` | Correo, dirección, método de envío, datos de facturación opcionales y pago | SSR | `addresses`, `orders` | 4 |
| `/checkout/confirmacion/[pedido]` | `checkout/confirmacion/[pedido].astro` | Resumen del pedido y siguiente paso (referencia de pago, tiempos) | SSR | `orders`, `order_items`, `payments` | 4 |
| `/contacto` | `contacto.astro` | Datos de contacto y formulario general | Estática + endpoint | `quote_requests` | 8 |
| `/eventos-y-mayoreo` | `eventos-y-mayoreo.astro` | Solicitud de cotización para eventos, bodas y compras al mayoreo | Estática + endpoint | `quote_requests`, `wholesale_tiers` | 8 |
| `/nosotros` | `nosotros.astro` | Historia, proceso artesanal, ingredientes | Estática | (ninguna) | 8 |
| `/envios`, `/devoluciones`, `/faq` | `envios.astro`, `devoluciones.astro`, `faq.astro` | Políticas y preguntas frecuentes | Estática | (ninguna) | 8 |
| `/privacidad`, `/terminos` | `privacidad.astro`, `terminos.astro` | Aviso de privacidad y términos y condiciones (requeridos antes de vender) | Estática | (ninguna) | 6 |

**Nota sobre el diseño anterior:** `index.html`, `productos.html` y `contacto.html` pasan a `/`, `/productos` y `/contacto`. El carrito, que antes era solo un ícono, se vuelve página propia (`/carrito`) además del cajón lateral.

## 4. Autenticación y cuenta de cliente

| Ruta | Archivo | Propósito | Acceso | Render | Etapa |
|---|---|---|---|---|---|
| `/iniciar-sesion` | `iniciar-sesion.astro` | Botón "Continuar con Google" | Público (redirige si ya hay sesión) | SSR | 5 |
| `/auth/callback` | `auth/callback.ts` | Recibe el código de Google, crea la sesión y redirige | Público | Servidor | 5 |
| `/cerrar-sesion` | `cerrar-sesion.ts` | Cierra la sesión (método POST) | Cliente | Servidor | 5 |
| `/cuenta` | `cuenta/index.astro` | Resumen de la cuenta | Cliente | SSR | 5 |
| `/cuenta/pedidos` | `cuenta/pedidos/index.astro` | Historial de pedidos | Cliente | SSR | 5 |
| `/cuenta/pedidos/[numero]` | `cuenta/pedidos/[numero].astro` | Detalle, estado y guía de rastreo | Cliente (solo sus pedidos) | SSR | 5 |
| `/cuenta/direcciones` | `cuenta/direcciones.astro` | Libreta de direcciones | Cliente | SSR | 5 |
| `/cuenta/perfil` | `cuenta/perfil.astro` | Nombre y teléfono | Cliente | SSR | 5 |

El pago como **invitado** (sin cuenta) queda permitido: reduce el abandono del carrito. Si el correo coincide con una cuenta, el pedido se vincula al iniciar sesión.

## 5. Panel de administración

Todas las rutas `/admin/*` exigen rol `admin` y llevan `noindex`.

| Ruta | Archivo | Propósito | Etapa |
|---|---|---|---|
| `/admin` | `admin/index.astro` | Resumen: pedidos pendientes, stock bajo, cotizaciones nuevas | 7 |
| `/admin/productos` | `admin/productos/index.astro` | Lista, búsqueda, activar o desactivar | 7 |
| `/admin/productos/nuevo` | `admin/productos/nuevo.astro` | Alta de producto con variantes e imágenes | 7 |
| `/admin/productos/[id]` | `admin/productos/[id].astro` | Edición de producto, variantes, precios, stock | 7 |
| `/admin/pedidos` | `admin/pedidos/index.astro` | Lista filtrable por estado | 7 |
| `/admin/pedidos/[numero]` | `admin/pedidos/[numero].astro` | Detalle, cambio de estado, guía de rastreo, notas internas | 7 |
| `/admin/cotizaciones` | `admin/cotizaciones/index.astro` | Solicitudes de eventos y mayoreo con su estado | 8 |
| `/admin/resenas` | `admin/resenas/index.astro` | Moderación de reseñas | 8 |

## 6. Endpoints de servidor (API)

Los endpoints viven en `src/pages/api/`. Los que escriben datos sensibles usan la clave `service_role` **solo en el servidor**.

| Método y ruta | Función | Acceso | Etapa |
|---|---|---|---|
| `POST /api/carrito/validar` | Verifica precios y stock reales antes de continuar | Público | 3 |
| `POST /api/checkout` | Crea el pedido y sus líneas, descuenta reserva de stock, devuelve el enlace de pago | Público | 4 |
| `POST /api/envio/cotizar` | Calcula el costo de envío por peso y código postal | Público | 6 |
| `POST /api/webhooks/mercadopago` (o el proveedor elegido) | Confirma el pago, marca el pedido como pagado, es idempotente | Firma del proveedor | 6 |
| `POST /api/cotizaciones` | Guarda una solicitud del formulario (con antispam) | Público | 8 |
| `POST /api/resenas` | Crea una reseña pendiente de moderación | Cliente | 8 |
| `POST /api/admin/...` | Operaciones del panel (estado de pedido, productos) | Admin | 7 |

## 7. Páginas del sistema

| Ruta | Archivo | Función |
|---|---|---|
| `/404` | `404.astro` | Página no encontrada, con enlace al catálogo |
| `/500` | `500.astro` | Error del servidor, mensaje claro y contacto |
| `/sitemap.xml` | generado (`@astrojs/sitemap`) | Mapa para buscadores |
| `/robots.txt` | `robots.txt.ts` | Excluye `/admin`, `/cuenta`, `/checkout`, `/carrito` |

## 8. Navegación

**Encabezado (todas las páginas):** Inicio · Productos · Contacto · cuenta (ícono) · carrito (ícono con contador).
Al pasar sobre "Productos" se despliegan las categorías: Velas, Belleza, Insumos, Moldes 3D.

**Pie de página:**
- *Tienda:* Velas, Belleza, Insumos, Moldes 3D
- *Ayuda:* Envíos, Devoluciones, Preguntas frecuentes, Contacto, Eventos y mayoreo
- *Legal:* Aviso de privacidad, Términos y condiciones

## 9. Reglas de protección y SEO

| Regla | Detalle |
|---|---|
| Protección por rol | `middleware.ts` revisa la sesión: `/cuenta/*` requiere cliente, `/admin/*` requiere admin. Sin permiso, redirige a `/iniciar-sesion` o responde 403. |
| No indexar | `noindex` en `/carrito`, `/checkout/*`, `/cuenta/*`, `/admin/*`, `/iniciar-sesion`. |
| Indexar | `/`, `/productos`, `/categoria/*`, `/productos/[slug]`, páginas informativas y legales. |
| URL canónica | Cada producto tiene una sola URL; las páginas filtradas o paginadas apuntan a la del catálogo base. |
| Datos estructurados | `Product` y `Offer` (schema.org) en el detalle para mostrar precio y disponibilidad en Google. |
| Redirecciones | Si se conservan URL del sitio anterior, `/pages/productos.html` redirige (301) a `/productos`. |

## 10. Orden de construcción

| Etapa | Páginas y endpoints | Resultado |
|---|---|---|
| 1 | `/`, `/productos`, layout (encabezado y pie) | Catálogo con datos reales |
| 2 | `/productos/[slug]`, `/categoria/[slug]` | Cada producto con su URL |
| 3 | `/carrito`, `api/carrito/validar` | Carrito funcional |
| 4 | `/checkout`, confirmación, `api/checkout` | Pedido guardado, sin pago |
| 5 | Inicio de sesión y `/cuenta/*` | Clientes con historial |
| 6 | Pagos, webhook, envíos, `/privacidad`, `/terminos` | Primera venta real |
| 7 | `/admin/*` | Tu esposa gestiona sola |
| 8 | Contacto, eventos y mayoreo, nosotros, ayuda, reseñas | Sitio completo |

Las páginas legales se anticipan a la etapa 6 porque deben existir antes de cobrar.

## 11. Estructura de carpetas resultante

```
src/
  pages/
    index.astro
    productos/ index.astro, [slug].astro
    categoria/[slug].astro
    carrito.astro
    checkout.astro
    checkout/confirmacion/[pedido].astro
    contacto.astro, eventos-y-mayoreo.astro, nosotros.astro
    envios.astro, devoluciones.astro, faq.astro
    privacidad.astro, terminos.astro
    iniciar-sesion.astro
    auth/callback.ts
    cerrar-sesion.ts
    cuenta/ index.astro, pedidos/, direcciones.astro, perfil.astro
    admin/ index.astro, productos/, pedidos/, cotizaciones/, resenas/
    api/ carrito/, checkout.ts, envio/, webhooks/, cotizaciones.ts, resenas.ts, admin/
    404.astro, 500.astro, robots.txt.ts
  layouts/ Base.astro, Cuenta.astro, Admin.astro
  components/ Header.astro, Footer.astro, ProductCard.astro, CartDrawer.astro ...
  lib/ supabase.ts, cart.ts, shipping.ts, payments.ts
  middleware.ts
  styles/ tokens.css, base.css
```
