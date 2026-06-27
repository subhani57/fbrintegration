import { ensureToastStack, showToast } from "fbr_dialog"

let progressBar = null
let progressInitialized = false

export function initFbrUi() {
  resetStuckFormControls()
  initProgressBar()
  initBootstrapComponents()
  initFlashNotifications()
  updateNavbarActiveLinks()
  syncEnvironmentSwitcher()
  initEnvironmentSwitcherVisibilitySync()
  initNavbarScroll()
  initRevealAnimations()
  initCountUpStats()
  initButtonRipples()
  initFormFocus()
  initTooltips()
}

export function prepareTurboCache() {
  resetStuckFormControls()
  disposeBootstrapComponents()
  disposeTooltips()
  resetMarkedElements()
  destroyFlatpickrInstances()
}

function resetStuckFormControls() {
  document.querySelectorAll("form.button_to button[disabled], form.button_to input[disabled]").forEach((el) => {
    el.disabled = false
    el.removeAttribute("disabled")
  })
}

function resetMarkedElements() {
  document.querySelectorAll("[data-fbr-count-done]").forEach((el) => {
    delete el.dataset.fbrCountDone
  })

  document.querySelectorAll("[data-fbr-ripple]").forEach((el) => {
    delete el.dataset.fbrRipple
    el.querySelectorAll(".fbr-btn-ripple__wave").forEach((wave) => wave.remove())
  })

  document.querySelectorAll("[data-fbr-focus]").forEach((el) => {
    delete el.dataset.fbrFocus
  })

  document.querySelectorAll("[data-fbr-tooltip]").forEach((el) => {
    delete el.dataset.fbrTooltip
  })

  document.querySelectorAll("[data-invoice-form-bound]").forEach((el) => {
    delete el.dataset.invoiceFormBound
  })

  document.querySelectorAll(".fbr-reveal-done").forEach((el) => {
    el.classList.remove("fbr-reveal-done", "fbr-reveal-visible", "fbr-reveal")
    el.style.removeProperty("--fbr-reveal-delay")
  })

  document.querySelector(".fbr-main-content")?.classList.remove("fbr-revealed")

  document.querySelectorAll(".fbr-flash-ready").forEach((el) => {
    el.classList.remove("fbr-flash-ready")
  })

  document.querySelectorAll(".fbr-notify").forEach((el) => el.remove())

  document.querySelectorAll(".alert.fbr-toast-ready").forEach((alert) => {
    alert.classList.remove("fbr-toast-ready", "fbr-toast", "fbr-toast--visible", "fbr-toast--hiding")
    alert.querySelector(".fbr-toast__timer")?.remove()
  })
}

function disposeTooltips() {
  if (typeof bootstrap === "undefined" || !bootstrap.Tooltip) return

  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach((el) => {
    bootstrap.Tooltip.getInstance(el)?.dispose()
  })
}

function initBootstrapComponents() {
  if (typeof bootstrap === "undefined") return

  document.querySelectorAll('[data-bs-toggle="dropdown"]').forEach((el) => {
    if (el.closest("[data-turbo-permanent]")) return
    bootstrap.Dropdown.getInstance(el)?.dispose()
    bootstrap.Dropdown.getOrCreateInstance(el)
  })

  document.querySelectorAll('[data-bs-toggle="collapse"]').forEach((el) => {
    if (el.closest("[data-turbo-permanent]") && bootstrap.Collapse.getInstance(el)) return
    bootstrap.Collapse.getInstance(el)?.dispose()
    bootstrap.Collapse.getOrCreateInstance(el, { toggle: false })
  })
}

function disposeBootstrapComponents() {
  if (typeof bootstrap === "undefined") return

  document.querySelectorAll('[data-bs-toggle="dropdown"]').forEach((el) => {
    if (el.closest("[data-turbo-permanent]")) return

    const instance = bootstrap.Dropdown.getInstance(el)
    if (instance) {
      instance.hide()
      instance.dispose()
    }
    el.classList.remove("show")
    el.setAttribute("aria-expanded", "false")
  })

  document.querySelectorAll(".dropdown-menu.show").forEach((menu) => {
    if (menu.closest("[data-turbo-permanent]")) return
    menu.classList.remove("show")
  })

  document.querySelectorAll('[data-bs-toggle="collapse"]').forEach((el) => {
    if (el.closest("[data-turbo-permanent]")) return
    bootstrap.Collapse.getInstance(el)?.dispose()
  })

  document.querySelectorAll('[data-controller~="navbar-dropdown"].show').forEach((el) => {
    el.classList.remove("show")
    el.querySelector(".dropdown-menu")?.classList.remove("show")
    el.querySelector("[data-navbar-dropdown-target='button']")?.classList.remove("show")
    el.querySelector("[data-navbar-dropdown-target='button']")?.setAttribute("aria-expanded", "false")
  })
}

function updateNavbarActiveLinks() {
  const nav = document.getElementById("fbr-main-navbar")
  if (!nav) return

  const path = window.location.pathname.replace(/\/$/, "") || "/"

  nav.querySelectorAll(".navbar-nav.me-auto .nav-link").forEach((link) => {
    const href = (link.getAttribute("href") || "").replace(/\/$/, "") || "/"
    if (!href || href.startsWith("#")) return

    const active = href === path || (href !== "/" && path.startsWith(`${href}/`))
    link.classList.toggle("active", active)
  })
}

export function syncEnvironmentSwitcher() {
  const current = document.body.dataset.fbrEnvironment
  const switcher = document.getElementById("fbr-env-switcher")
  if (!current || !switcher) return

  switcher.querySelectorAll("[data-fbr-environment]").forEach((el) => {
    const env = el.dataset.fbrEnvironment
    const active = env === current
    el.classList.toggle("fbr-env-switcher__btn--active", active)
    el.classList.toggle("fbr-env-switcher__btn--production", active && env === "production")
  })
}

function initEnvironmentSwitcherVisibilitySync() {
  if (window._fbrEnvVisibilityBound) return
  window._fbrEnvVisibilityBound = true

  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState === "visible") {
      syncEnvironmentSwitcher()
    }
  })

  document.addEventListener("turbo:load", syncEnvironmentSwitcher)
  document.addEventListener("turbo:render", syncEnvironmentSwitcher)
}

function destroyFlatpickrInstances() {
  if (typeof flatpickr === "undefined") return

  document.querySelectorAll(".datepicker").forEach((el) => {
    el._flatpickr?.destroy()
  })
}

function initProgressBar() {
  if (!progressBar) {
    progressBar = document.createElement('div')
    progressBar.className = 'fbr-progress-bar'
    progressBar.innerHTML = '<div class="fbr-progress-bar__fill"></div>'
    document.body.appendChild(progressBar)
  }

  if (progressInitialized) return
  progressInitialized = true

  document.addEventListener('turbo:visit', showProgress)
  document.addEventListener('turbo:load', hideProgress)
  document.addEventListener('turbo:frame-load', hideProgress)
}

function showProgress() {
  if (!progressBar) return
  progressBar.classList.add('fbr-progress-bar--active')
  const fill = progressBar.querySelector('.fbr-progress-bar__fill')
  if (fill) {
    fill.style.width = '0%'
    requestAnimationFrame(() => {
      fill.style.width = '70%'
    })
  }
}

function hideProgress() {
  if (!progressBar) return
  const fill = progressBar.querySelector('.fbr-progress-bar__fill')
  if (fill) fill.style.width = '100%'
  setTimeout(() => progressBar.classList.remove('fbr-progress-bar--active'), 280)
}

function initFlashNotifications() {
  ensureToastStack()

  document.querySelectorAll(".fbr-flash:not(.fbr-flash-ready)").forEach((flash) => {
    flash.classList.add("fbr-flash-ready")

    const variant = flash.dataset.fbrFlashVariant
      || (flash.classList.contains("alert-danger") ? "danger" : "success")
    const text = flash.querySelector(".fbr-flash__text")?.textContent.trim()
      || flash.textContent.replace(/\s+/g, " ").trim()

    if (text) {
      showToast(text, {
        variant: variant === "danger" ? "danger" : "success",
        duration: variant === "danger" ? 8000 : 5500
      })
    }

    flash.remove()
  })
}

function initNavbarScroll() {
  const nav = document.querySelector('.navbar-fbr')
  if (!nav) return

  const onScroll = () => {
    nav.classList.toggle('navbar-fbr--scrolled', window.scrollY > 12)
  }

  onScroll()
  window.removeEventListener('scroll', nav._fbrScrollHandler)
  nav._fbrScrollHandler = onScroll
  window.addEventListener('scroll', onScroll, { passive: true })
}

function initRevealAnimations() {
  const main = document.querySelector('.fbr-main-content')
  if (main && !main.classList.contains('fbr-revealed')) {
    main.classList.add('fbr-revealed')
  }

  const targets = document.querySelectorAll(
    '.card:not(.fbr-reveal-done), .auth-card:not(.fbr-reveal-done), .invoice-form-section-card:not(.fbr-reveal-done), .invoice-hero:not(.fbr-reveal-done), .fbr-page-header:not(.fbr-reveal-done)'
  )

  if (!('IntersectionObserver' in window)) {
    targets.forEach((el) => el.classList.add('fbr-reveal-done', 'fbr-reveal-visible'))
    return
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return
        entry.target.classList.add('fbr-reveal-visible', 'fbr-reveal-done')
        observer.unobserve(entry.target)
      })
    },
    { rootMargin: '0px 0px -40px 0px', threshold: 0.08 }
  )

  targets.forEach((el, i) => {
    el.classList.add('fbr-reveal')
    el.style.setProperty('--fbr-reveal-delay', `${Math.min(i * 55, 320)}ms`)
    observer.observe(el)
  })
}

function initCountUpStats() {
  document.querySelectorAll('[data-fbr-count]').forEach((el) => {
    if (el.dataset.fbrCountDone) return

    const target = parseInt(el.dataset.fbrCount, 10)
    if (Number.isNaN(target)) return

    el.dataset.fbrCountDone = 'true'
    animateValue(el, 0, target, 900)
  })
}

function animateValue(el, start, end, duration) {
  const startTime = performance.now()

  const step = (now) => {
    const progress = Math.min((now - startTime) / duration, 1)
    const eased = 1 - Math.pow(1 - progress, 3)
    el.textContent = Math.round(start + (end - start) * eased)
    if (progress < 1) requestAnimationFrame(step)
  }

  requestAnimationFrame(step)
}

function initButtonRipples() {
  document.querySelectorAll('.btn-primary, .btn-success, .btn-outline-primary').forEach((btn) => {
    if (btn.dataset.fbrRipple) return
    btn.dataset.fbrRipple = 'true'
    btn.classList.add('fbr-btn-ripple')

    btn.addEventListener('click', (e) => {
      const rect = btn.getBoundingClientRect()
      const ripple = document.createElement('span')
      ripple.className = 'fbr-btn-ripple__wave'
      ripple.style.left = `${e.clientX - rect.left}px`
      ripple.style.top = `${e.clientY - rect.top}px`
      btn.appendChild(ripple)
      ripple.addEventListener('animationend', () => ripple.remove())
    })
  })
}

function initFormFocus() {
  document.querySelectorAll('.form-control, .form-select').forEach((input) => {
    if (input.dataset.fbrFocus) return
    input.dataset.fbrFocus = 'true'

    input.addEventListener('focus', () => {
      input.closest('.mb-3, .invoice-form-input, .input')?.classList.add('fbr-field-focus')
    })
    input.addEventListener('blur', () => {
      input.closest('.mb-3, .invoice-form-input, .input')?.classList.remove('fbr-field-focus')
    })
  })
}

function initTooltips() {
  if (typeof bootstrap === 'undefined' || !bootstrap.Tooltip) return

  document.querySelectorAll('[data-bs-toggle="tooltip"]').forEach((el) => {
    if (el.dataset.fbrTooltip) return
    el.dataset.fbrTooltip = 'true'
    bootstrap.Tooltip.getOrCreateInstance(el)
  })
}
