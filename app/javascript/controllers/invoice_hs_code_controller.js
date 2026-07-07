import { Controller } from "@hotwired/stimulus"
import { getHsCodesCatalog, loadHsCodesCatalog, searchHsCodes } from "hs_codes_cache"

export default class extends Controller {
  static targets = ["input", "hidden", "results"]
  static values = {
    catalogUrl: { type: String, default: "/api/v1/reference_data/hs_codes" },
    searchUrl: { type: String, default: "/api/v1/reference_data/hs_codes/search" },
    selected: String
  }

  connect() {
    this.catalog = getHsCodesCatalog()
    this.catalogLoading = false
    this.remoteSearchTimer = null
    this.blurTimer = null
    this.onDocumentClick = this.onDocumentClick.bind(this)
    document.addEventListener("click", this.onDocumentClick)

    if (this.selectedValue) {
      this.inputTarget.value = this.selectedValue
      this.hiddenTarget.value = this.selectedValue
    }

    this.ensureCatalogLoaded()
  }

  disconnect() {
    document.removeEventListener("click", this.onDocumentClick)
    if (this.remoteSearchTimer) clearTimeout(this.remoteSearchTimer)
    if (this.blurTimer) clearTimeout(this.blurTimer)
  }

  onFocus() {
    this.ensureCatalogLoaded()
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

    if (query.length < 2) {
      this.hideResults()
      return
    }

    if (this.catalog?.length) {
      this.renderResults(searchHsCodes(this.catalog, query))
      return
    }

    this.showLoading()
    this.ensureCatalogLoaded().then(() => {
      if (this.catalog?.length) {
        this.renderResults(searchHsCodes(this.catalog, query))
        return
      }

      if (this.remoteSearchTimer) clearTimeout(this.remoteSearchTimer)
      this.remoteSearchTimer = setTimeout(() => this.fetchResults(query), 150)
    })
  }

  ensureCatalogLoaded() {
    if (this.catalog?.length) return Promise.resolve(this.catalog)
    if (this.catalogLoading) return loadHsCodesCatalog(this.catalogUrlValue)

    this.catalogLoading = true
    return loadHsCodesCatalog(this.catalogUrlValue).then((catalog) => {
      this.catalogLoading = false
      if (catalog?.length) this.catalog = catalog
      return this.catalog
    })
  }

  async fetchResults(query) {
    this.showLoading()

    try {
      const url = `${this.searchUrlValue}?q=${encodeURIComponent(query)}`
      const response = await fetch(url, {
        headers: {
          Accept: "application/json",
          "X-Requested-With": "XMLHttpRequest"
        },
        credentials: "same-origin"
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
