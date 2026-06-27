// Toasts + re-exports for confirm modal (Bootstrap-based, not Turbo/Stimulus).

import { fbrConfirm, showFbrAlert, showFbrConfirm, hideFbrConfirmModal } from "fbr_confirm_modal"

export { fbrConfirm as turboConfirm, showFbrConfirm as showConfirm, showFbrAlert as showAlert, hideFbrConfirmModal as closeActiveDialog }

const ICONS = {
  info: "fa-circle-info",
  success: "fa-circle-check",
  warning: "fa-triangle-exclamation",
  danger: "fa-circle-exclamation"
}

export function setupFbrDialogs() {
  window.alert = (message) => showFbrAlert(message)
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

function getPortal() {
  let root = document.getElementById("fbr-ui-portal")
  if (!root?.isConnected) {
    root = document.createElement("div")
    root.id = "fbr-ui-portal"
    document.documentElement.appendChild(root)
  }
  return root
}

export function ensureToastStack() {
  let stack = document.getElementById("fbr-toast-stack")
  if (!stack?.isConnected) {
    stack = document.createElement("div")
    stack.id = "fbr-toast-stack"
    stack.className = "fbr-toast-stack"
    stack.setAttribute("aria-live", "polite")
    stack.setAttribute("aria-atomic", "true")
    getPortal().appendChild(stack)
  }
  return stack
}

function escapeHtml(text) {
  return String(text)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
}
