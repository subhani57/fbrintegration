import { Controller } from "@hotwired/stimulus"

// User menu dropdown — Turbo-safe, no Bootstrap Dropdown instance lifecycle issues
export default class extends Controller {
  static targets = ["button", "menu"]

  connect() {
    this.onDocumentClick = this.onDocumentClick.bind(this)
    this.onKeydown = this.onKeydown.bind(this)
  }

  disconnect() {
    this.close()
    document.removeEventListener("click", this.onDocumentClick)
    document.removeEventListener("keydown", this.onKeydown)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.closeOtherDropdowns()
    this.element.classList.add("show")
    this.menuTarget.classList.add("show")
    this.buttonTarget.classList.add("show")
    this.buttonTarget.setAttribute("aria-expanded", "true")

    document.addEventListener("click", this.onDocumentClick)
    document.addEventListener("keydown", this.onKeydown)
  }

  closeOtherDropdowns() {
    document.querySelectorAll("[data-controller~='navbar-dropdown'].show").forEach((el) => {
      if (el === this.element) return
      el.classList.remove("show")
      el.querySelector("[data-navbar-dropdown-target='menu']")?.classList.remove("show")
      el.querySelector("[data-navbar-dropdown-target='button']")?.classList.remove("show")
      el.querySelector("[data-navbar-dropdown-target='button']")?.setAttribute("aria-expanded", "false")
    })
  }

  close() {
    this.element.classList.remove("show")
    this.menuTarget.classList.remove("show")
    this.buttonTarget.classList.remove("show")
    this.buttonTarget.setAttribute("aria-expanded", "false")

    document.removeEventListener("click", this.onDocumentClick)
    document.removeEventListener("keydown", this.onKeydown)
  }

  onDocumentClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  onKeydown(event) {
    if (event.key === "Escape") this.close()
  }

  get isOpen() {
    return this.menuTarget.classList.contains("show")
  }
}
