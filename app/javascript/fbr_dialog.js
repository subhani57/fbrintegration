// Custom alert / confirm dialogs — replaces browser built-ins app-wide

let dialogRoot = null
let dialogSetup = false
let activeResolver = null

const ICONS = {
  info: "fa-circle-info",
  success: "fa-circle-check",
  warning: "fa-triangle-exclamation",
  danger: "fa-circle-exclamation"
}

export function setupFbrDialogs() {
  if (dialogSetup) return
  dialogSetup = true

  ensureDialogRoot()
  bindDialogEvents()

  if (window.Turbo?.config?.forms) {
    window.Turbo.config.forms.confirm = turboConfirm
  } else if (window.Turbo?.setConfirmMethod) {
    window.Turbo.setConfirmMethod(turboConfirm)
  }

  window.alert = (message) => {
    showAlert(message)
  }
}

export function turboConfirm(message) {
  const destructive = isDestructiveAction(message)
  return showConfirm(message, {
    title: destructive ? "Please confirm" : "Are you sure?",
    confirmLabel: destructive ? "Yes, continue" : "Confirm",
    variant: destructive ? "danger" : "warning"
  })
}

export function showAlert(message, { title = "Notice", variant = "info" } = {}) {
  return openDialog({
    title,
    message,
    variant,
    mode: "alert"
  })
}

export function showConfirm(message, {
  title = "Are you sure?",
  confirmLabel = "Confirm",
  cancelLabel = "Cancel",
  variant = "warning"
} = {}) {
  return openDialog({
    title,
    message,
    variant,
    mode: "confirm",
    confirmLabel,
    cancelLabel
  })
}

export function showToast(message, { variant = "success", duration = 5500, title = null } = {}) {
  const stack = ensureToastStack()
  const toast = document.createElement("div")
  toast.className = `fbr-notify fbr-notify--${variant}`
  toast.setAttribute("role", "alert")

  const icon = ICONS[variant] || ICONS.info
  toast.innerHTML = `
    <div class="fbr-notify__icon"><i class="fas ${icon}"></i></div>
    <div class="fbr-notify__body">
      ${title ? `<div class="fbr-notify__title">${escapeHtml(title)}</div>` : ""}
      <div class="fbr-notify__message">${escapeHtml(message)}</div>
    </div>
    <button type="button" class="fbr-notify__close" aria-label="Dismiss">&times;</button>
    <div class="fbr-notify__timer"></div>
  `

  const timer = toast.querySelector(".fbr-notify__timer")
  if (timer) timer.style.animationDuration = `${duration}ms`

  const close = () => {
    toast.classList.add("fbr-notify--hiding")
    setTimeout(() => toast.remove(), 280)
  }

  toast.querySelector(".fbr-notify__close")?.addEventListener("click", close)
  setTimeout(close, duration)

  stack.appendChild(toast)
  requestAnimationFrame(() => toast.classList.add("fbr-notify--visible"))
}

export function ensureToastStack() {
  let stack = document.getElementById("fbr-toast-stack")
  if (!stack) {
    stack = document.createElement("div")
    stack.id = "fbr-toast-stack"
    stack.className = "fbr-toast-stack"
    stack.setAttribute("aria-live", "polite")
    stack.setAttribute("aria-atomic", "true")
    document.body.appendChild(stack)
  }
  return stack
}

export function closeActiveDialog() {
  if (!dialogRoot || dialogRoot.hidden) return
  finishDialog(false)
}

function ensureDialogRoot() {
  if (dialogRoot) return dialogRoot

  dialogRoot = document.createElement("div")
  dialogRoot.id = "fbr-dialog-root"
  dialogRoot.className = "fbr-dialog-root"
  dialogRoot.hidden = true
  dialogRoot.innerHTML = `
    <div class="fbr-dialog-backdrop" data-fbr-dialog-dismiss="true"></div>
    <div class="fbr-dialog" role="alertdialog" aria-modal="true" aria-labelledby="fbr-dialog-title" aria-describedby="fbr-dialog-message">
      <div class="fbr-dialog__icon"><i class="fas fa-circle-info"></i></div>
      <h2 class="fbr-dialog__title" id="fbr-dialog-title"></h2>
      <p class="fbr-dialog__message" id="fbr-dialog-message"></p>
      <div class="fbr-dialog__actions">
        <button type="button" class="btn btn-outline-secondary fbr-dialog__cancel">Cancel</button>
        <button type="button" class="btn btn-primary fbr-dialog__confirm">OK</button>
      </div>
    </div>
  `
  document.body.appendChild(dialogRoot)
  return dialogRoot
}

function bindDialogEvents() {
  const root = ensureDialogRoot()

  root.querySelector(".fbr-dialog__confirm")?.addEventListener("click", () => finishDialog(true))
  root.querySelector(".fbr-dialog__cancel")?.addEventListener("click", () => finishDialog(false))
  root.querySelector(".fbr-dialog-backdrop")?.addEventListener("click", () => {
    if (root.dataset.mode === "confirm") finishDialog(false)
  })

  document.addEventListener("keydown", (event) => {
    if (dialogRoot?.hidden) return
    if (event.key === "Escape") finishDialog(false)
  })
}

function openDialog({ title, message, variant, mode, confirmLabel = "OK", cancelLabel = "Cancel" }) {
  closeActiveDialog()

  const root = ensureDialogRoot()
  root.hidden = false
  root.dataset.mode = mode
  root.classList.remove("fbr-dialog-root--alert", "fbr-dialog-root--confirm")
  root.classList.add(mode === "alert" ? "fbr-dialog-root--alert" : "fbr-dialog-root--confirm")
  root.classList.remove("fbr-dialog-root--info", "fbr-dialog-root--success", "fbr-dialog-root--warning", "fbr-dialog-root--danger")
  root.classList.add(`fbr-dialog-root--${variant}`)

  const iconEl = root.querySelector(".fbr-dialog__icon i")
  if (iconEl) iconEl.className = `fas ${ICONS[variant] || ICONS.info}`

  root.querySelector(".fbr-dialog__title").textContent = title
  root.querySelector(".fbr-dialog__message").textContent = message

  const cancelBtn = root.querySelector(".fbr-dialog__cancel")
  const confirmBtn = root.querySelector(".fbr-dialog__confirm")

  if (mode === "alert") {
    cancelBtn.hidden = true
    confirmBtn.textContent = "OK"
    confirmBtn.className = "btn btn-primary fbr-dialog__confirm"
  } else {
    cancelBtn.hidden = false
    cancelBtn.textContent = cancelLabel
    confirmBtn.textContent = confirmLabel
    confirmBtn.className = variant === "danger"
      ? "btn btn-danger fbr-dialog__confirm"
      : "btn btn-primary fbr-dialog__confirm"
  }

  document.body.classList.add("fbr-dialog-open")
  requestAnimationFrame(() => root.classList.add("fbr-dialog-root--visible"))
  confirmBtn.focus()

  return new Promise((resolve) => {
    activeResolver = resolve
  })
}

function finishDialog(result) {
  if (!dialogRoot || dialogRoot.hidden) return

  dialogRoot.classList.remove("fbr-dialog-root--visible")
  document.body.classList.remove("fbr-dialog-open")

  setTimeout(() => {
    dialogRoot.hidden = true
    activeResolver?.(result)
    activeResolver = null
  }, 180)
}

function isDestructiveAction(message) {
  return /delete|cancel|remove|logout|production|submit|send test|discard/i.test(String(message))
}

function escapeHtml(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}
