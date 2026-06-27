# Pin npm packages by running ./bin/importmap

pin "application"
pin "fbr_confirm_modal", to: "fbr_confirm_modal.js"
pin "fbr_ui", to: "fbr_ui.js"
pin "fbr_dialog", to: "fbr_dialog.js"
pin "@hotwired/turbo-rails", to: "@hotwired--turbo-rails.js" # @8.0.20
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@hotwired/turbo", to: "@hotwired--turbo.js" # @8.0.20
pin "@rails/actioncable/src", to: "@rails--actioncable--src.js" # @8.1.100
