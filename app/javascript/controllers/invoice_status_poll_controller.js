import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    status: String,
    retryUrl: String
  }

  connect() {
    this.attempts = 0
    this.maxAttempts = 120
    this.recovered = false
    this.poll()
    this.timer = window.setInterval(() => this.poll(), 1000)
  }

  disconnect() {
    this.stopPolling()
  }

  stopPolling() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  refreshPage() {
    this.stopPolling()

    if (typeof Turbo !== "undefined") {
      Turbo.cache.clear()
      Turbo.visit(window.location.href, { action: "replace" })
      return
    }

    window.location.reload()
  }

  pollUrl() {
    const base = this.urlValue
    if (this.attempts !== 5 || this.recovered) return base

    this.recovered = true
    const separator = base.includes("?") ? "&" : "?"
    return `${base}${separator}recover=1`
  }

  async poll() {
    if (!this.urlValue || !this.statusValue) return

    this.attempts += 1

    if (this.attempts > this.maxAttempts) {
      this.showTimeoutMessage()
      this.stopPolling()
      return
    }

    try {
      const response = await fetch(this.pollUrl(), {
        headers: {
          Accept: "application/json",
          "X-Requested-With": "XMLHttpRequest"
        },
        credentials: "same-origin",
        cache: "no-store"
      })
      if (!response.ok) return

      const data = await response.json()
      if (data.status !== this.statusValue) {
        this.refreshPage()
      }
    } catch (_) {
      // Keep polling on transient errors.
    }
  }

  showTimeoutMessage() {
    const body = this.element.querySelector("div:last-child")
    if (!body) return

    body.innerHTML = `
      <strong>Taking longer than expected</strong>
      <div class="small mb-0 opacity-75">
        Background processing may not be running. Try refreshing the page or run Validate again.
        <button type="button" class="btn btn-sm btn-light ms-2" data-action="click->invoice-status-poll#refreshPage">
          Refresh now
        </button>
      </div>
    `
  }
}
