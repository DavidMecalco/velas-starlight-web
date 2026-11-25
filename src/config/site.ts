/**
 * Datos de contacto y condiciones del negocio.
 *
 * TODOS LOS CAMPOS SON OPCIONALES. Mientras un campo esté vacío, su bloque
 * no aparece en /contacto ni en /eventos-y-mayoreo, y las frases que lo
 * mencionan se muestran sin el dato. No poner valores de relleno.
 *
 * Formato esperado (los ejemplos son ficticios):
 *  - whatsapp:            número con lada de país, como se mostrará ("+52 000 000 0000").
 *                         Para el enlace wa.me se usan solo los dígitos.
 *  - email:               correo de atención.
 *  - horario:             días y horas de atención ("lunes a viernes, de 10:00 a 18:00").
 *  - zona:                ciudad o zona de entrega.
 *  - tiempoRespuesta:     completa la frase "Respondemos en …" ("menos de 24 horas").
 *  - pedidoMinimo:        texto del pedido mínimo por tipo de pedido.
 *  - anticipacionEventos: completa la frase "… para pedidos de evento" ("dos semanas").
 */
export interface SiteConfig {
  whatsapp?: string;
  email?: string;
  horario?: string;
  zona?: string;
  tiempoRespuesta?: string;
  pedidoMinimo?: string;
  anticipacionEventos?: string;
}

export const siteConfig: SiteConfig = {};

/** Configuración sin espacios sobrantes; un campo vacío queda como `undefined`. */
export const site: SiteConfig = Object.fromEntries(
  Object.entries(siteConfig)
    .map(([key, value]) => [key, typeof value === "string" ? value.trim() : ""])
    .filter(([, value]) => value !== ""),
);

/** Enlace de WhatsApp (https://wa.me/<dígitos>) o `undefined` si no hay número. */
export function whatsappUrl(number = site.whatsapp): string | undefined {
  const digits = (number ?? "").replace(/\D/g, "");
  return digits ? `https://wa.me/${digits}` : undefined;
}
