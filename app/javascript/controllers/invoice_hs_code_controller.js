import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hidden", "results"]
  static values = {
    url: { type: String, default: "/api/v1/reference_data/hs_codes/search" },
    selected: String
  }

  connect() {
    this.debounceTimer = null
    this.blurTimer = null
    this.onDocumentClick = this.onDocumentClick.bind(this)
    document.addEventListener("click", this.onDocumentClick)

    if (this.selectedValue) {
      this.inputTarget.value = this.selectedValue
      this.hiddenTarget.value = this.selectedValue
    }
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
    if (this.debounceTimer) clearTimeout(this.debounceTimer)
    if (this.blurTimer) clearTimeout(this.blurTimer)
  }

  onFocus() {
    const query = this.inputTarget.value.trim()
    if (query.length >= 2) this.search()
  }

  onBlur() {
    this.blurTimer = setTimeout(() => this.hideResults(), 150)
  }

  onDocumentClick(event) {
    if (!this.element.contains(event.target)) {
      this.hideResults()
    }
  }

  keydown(event) {
    if (event.key === "Escape") {
      this.hideResults()
      this.inputTarget.blur()
    }
  }

  search() {
    const query = this.inputTarget.value.trim()

    if (this.debounceTimer) clearTimeout(this.debounceTimer)

    if (query.length < 2) {
      this.hideResults()
      return
    }

    this.debounceTimer = setTimeout(() => this.fetchResults(query), 200)
  }

  async fetchResults(query) {
    this.showLoading()

    try {
      const url = `${this.urlValue}?q=${encodeURIComponent(query)}`
      const response = await fetch(url, {
        headers: {
          Accept: "application/json",
          "X-Requested-With": "XMLHttpRequest"
        },
        credentials: "same-origin",
        cache: "no-store"
      })

      if (!response.ok) {
        this.showError("Could not load HS codes. Please try again.")
        return
      }

      const data = await response.json()
      if (data.error) {
        this.showError(data.error)
        return
      }

      this.renderResults(Array.isArray(data) ? data : [])
    } catch (_) {
      this.showError("Could not load HS codes. Check your connection.")
    }
  }

  showLoading() {
    this.resultsTarget.hidden = false
    this.resultsTarget.innerHTML = '<div class="invoice-hs-code-results__status">Searching…</div>'
  }

  showError(message) {
    this.resultsTarget.hidden = false
    this.resultsTarget.innerHTML = `<div class="invoice-hs-code-results__status invoice-hs-code-results__status--error">${message}</div>`
  }

  renderResults(items) {
    this.resultsTarget.innerHTML = ""

    if (items.length === 0) {
      this.resultsTarget.innerHTML = '<div class="invoice-hs-code-results__status">No matching HS codes</div>'
      this.resultsTarget.hidden = false
      return
    }

    items.forEach((item) => {
      const code = item.code || item.hS_CODE || item.HS_CODE || ""
      if (!code) return

      const button = document.createElement("button")
      button.type = "button"
      button.className = "invoice-hs-code-results__option"
      button.textContent = this.formatLabel(item)
      button.addEventListener("mousedown", (event) => event.preventDefault())
      button.addEventListener("click", () => this.pick(code))
      this.resultsTarget.appendChild(button)
    })

    this.resultsTarget.hidden = false
  }

  pick(code) {
    this.inputTarget.value = code
    this.hiddenTarget.value = code
    this.hideResults()
    this.hiddenTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }

  hideResults() {
    this.resultsTarget.hidden = true
    this.resultsTarget.innerHTML = ""
  }

  formatLabel(item) {
    const code = item.code || item.hS_CODE || item.HS_CODE || ""
    const desc = item.description || item.DESCRIPTION || ""
    if (!desc) return code
    return `${code} — ${desc.substring(0, 60)}`
  }
}
