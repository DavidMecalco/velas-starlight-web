/**
 * Mejora progresiva de los formularios de solicitud (InquiryForm.astro).
 *
 * - Valida al enviar y escribe el error en texto debajo de cada campo.
 * - Muestra el estado de envío ("Enviando…") y bloquea envíos dobles.
 * - Muestra éxito, "no disponible aún" (endpoint inexistente o sin red) o error.
 *
 * Sin JavaScript, el navegador valida con `required`/`type` y hace un POST normal.
 * No registra en consola ningún dato del formulario.
 */

type Control = HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement;
type NoticeKind = "success" | "unavailable" | "error";

/** Respuestas que significan "el endpoint todavía no existe". */
const NOT_AVAILABLE = new Set([404, 405, 501]);

function errorFor(control: Control): string {
  const v = control.validity;
  if (v.valid) return "";
  if (v.valueMissing) return control.dataset.requiredMessage || "Completa este campo.";
  if (v.typeMismatch && control.type === "email") {
    return control.dataset.invalidMessage || "Revisa el correo; debe verse como nombre@correo.com.";
  }
  if (v.rangeUnderflow || v.stepMismatch || v.badInput) {
    return control.dataset.invalidMessage || "Escribe un número entero mayor que cero.";
  }
  if (v.tooLong) return "El texto es demasiado largo.";
  return control.dataset.invalidMessage || "Revisa este campo.";
}

function showError(control: Control, message: string): void {
  const error = document.getElementById(`${control.id}-error`);
  if (error) error.textContent = message;
  if (message) control.setAttribute("aria-invalid", "true");
  else control.removeAttribute("aria-invalid");
}

function controlsOf(form: HTMLFormElement): Control[] {
  // Solo los campos visibles con id (la trampa contra spam no tiene error que mostrar).
  return Array.from(form.querySelectorAll<Control>("input[id^='field-'], select[id^='field-'], textarea[id^='field-']"));
}

function showNotice(form: HTMLFormElement, kind: NoticeKind | null): void {
  form.querySelectorAll<HTMLElement>("[data-notice]").forEach((notice) => {
    notice.hidden = notice.dataset.notice !== kind;
    if (!notice.hidden) notice.focus();
  });
}

function setSending(button: HTMLButtonElement, sending: boolean): void {
  if (sending) {
    button.setAttribute("aria-disabled", "true");
    button.textContent = "Enviando…";
  } else {
    button.removeAttribute("aria-disabled");
    button.textContent = button.dataset.label ?? button.textContent;
  }
}

function enhance(form: HTMLFormElement): void {
  const button = form.querySelector<HTMLButtonElement>("[data-submit]");
  if (!button) return;
  form.noValidate = true;
  let sending = false;

  // Al corregir un campo con error, el mensaje se actualiza al salir de él.
  controlsOf(form).forEach((control) => {
    control.addEventListener("blur", () => {
      if (control.getAttribute("aria-invalid") === "true") showError(control, errorFor(control));
    });
  });

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (sending) return;

    const controls = controlsOf(form);
    let firstInvalid: Control | null = null;
    for (const control of controls) {
      const message = errorFor(control);
      showError(control, message);
      if (message && !firstInvalid) firstInvalid = control;
    }
    if (firstInvalid) {
      showNotice(form, null);
      firstInvalid.focus();
      return;
    }

    sending = true;
    setSending(button, true);
    showNotice(form, null);

    let kind: NoticeKind;
    try {
      const response = await fetch(form.action, {
        method: "POST",
        body: new FormData(form),
        headers: { Accept: "application/json" },
      });
      kind = response.ok ? "success" : NOT_AVAILABLE.has(response.status) ? "unavailable" : "error";
    } catch {
      kind = "unavailable";
    }

    sending = false;
    setSending(button, false);
    if (kind === "success") {
      form.reset();
      controls.forEach((control) => showError(control, ""));
    }
    showNotice(form, kind);
  });
}

export function enhanceInquiryForms(): void {
  document.querySelectorAll<HTMLFormElement>("form[data-inquiry-form]").forEach(enhance);
}
