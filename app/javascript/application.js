import { setupFbrDialogs, closeActiveDialog } from "fbr_dialog"
import "@hotwired/turbo-rails"
import "controllers"
import { initFbrUi, prepareTurboCache } from "fbr_ui"

const bootPage = () => {
  setupFbrDialogs()
  initFbrUi()
}

document.addEventListener("turbo:load", bootPage)
document.addEventListener("turbo:before-visit", closeActiveDialog)
document.addEventListener("turbo:before-cache", () => {
  closeActiveDialog()
  prepareTurboCache()
})

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", bootPage)
} else {
  bootPage()
}
