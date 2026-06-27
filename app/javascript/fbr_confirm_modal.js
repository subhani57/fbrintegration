// Delegates to inline boot script (window.fbrConfirm) — survives Turbo navigation.

export function hideFbrConfirmModal() {
  if (typeof window.fbrHideConfirm === "function") {
    window.fbrHideConfirm()
  }
}

export function showFbrConfirm(message, options = {}) {
  if (typeof window.fbrConfirm === "function") {
    return window.fbrConfirm(message)
  }
  return Promise.resolve(window.confirm(message))
}

export function showFbrAlert(message, { title = "Notice" } = {}) {
  return showFbrConfirm(message, { title, alert: true })
}

export function fbrConfirm(message) {
  if (typeof window.fbrConfirm === "function") {
    return window.fbrConfirm(message)
  }
  return Promise.resolve(window.confirm(message))
}
