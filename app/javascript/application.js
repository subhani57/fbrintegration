import "@hotwired/turbo-rails"
import "controllers"
import { setupFbrDialogs, closeActiveDialog } from "fbr_dialog"
import { initFbrUi, prepareTurboCache } from "fbr_ui"

setupFbrDialogs()

const bootFbrUi = () => initFbrUi()

document.addEventListener("turbo:load", bootFbrUi)
document.addEventListener("turbo:before-cache", () => {
  closeActiveDialog()
  prepareTurboCache()
})

if (document.readyState !== "loading") {
  bootFbrUi()
}
