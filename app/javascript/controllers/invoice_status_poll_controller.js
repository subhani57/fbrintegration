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
    this.retried = false
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
    window.location.reload()
  }

  async poll() {
    if (!this.urlValue || !this.statusValue) return

    this.attempts += 1
    if (this.attempts > this.maxAttempts) {
      this.stopPolling()
      return
    }

    try {
      const response = await fetch(this.urlValue, {
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
        return
      }

      if (!this.retried && this.attempts >= 3 && this.hasRetryUrlValue) {
        this.retried = true
        await this.triggerRetry()
      }
    } catch (_) {
      // Keep polling on transient errors.
    }
  }

  async triggerRetry() {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      await fetch(this.retryUrlValue, {
        method: "POST",
        headers: {
          Accept: "text/vnd.turbo-stream.html, text/html",
          "X-CSRF-Token": csrfToken,
          "X-Requested-With": "XMLHttpRequest"
        },
        credentials: "same-origin"
      })
    } catch (_) {
      // Polling will continue.
    }
  }
}
