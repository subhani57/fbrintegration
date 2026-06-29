import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onInput = this.handleInput.bind(this)
    this.onClick = this.handleClick.bind(this)
    this.onChange = this.handleChange.bind(this)

    this.element.addEventListener("input", this.onInput)
    this.element.addEventListener("click", this.onClick)
    this.element.addEventListener("change", this.onChange)

    this.initDatepickers()
    this.renumberItems()
    this.initBuyerCompanySelect()
    this.initInvoiceTypeToggle()
    this.initVerifyBuyer()
    this.loadUOMForItems()
    this.calculateTotals()
  }

  disconnect() {
    this.element.removeEventListener("input", this.onInput)
    this.element.removeEventListener("click", this.onClick)
    this.element.removeEventListener("change", this.onChange)
    this.destroyDatepickers()
  }

  addItem(event) {
    event.preventDefault()

    const itemsContainer = document.getElementById("invoice-items")
    const template = document.getElementById("item-fields-template")
    if (!itemsContainer || !template) return

    const newItem = template.content.cloneNode(true)
    const timestamp = Date.now()

    newItem.querySelectorAll("[name]").forEach((el) => {
      el.name = el.name.replace(/INDEX/, timestamp)
    })

    itemsContainer.appendChild(newItem)
    document.getElementById("no-items")?.classList.add("d-none")
    this.renumberItems()
    this.loadUOMForItems()
    this.calculateTotals()
    itemsContainer.lastElementChild?.scrollIntoView({ behavior: "smooth", block: "nearest" })
  }

  handleInput(event) {
    if (event.target.matches(".item-quantity, .item-unit-price, .item-tax-rate")) {
      this.calculateItemTotal(event.target.closest(".invoice-item"))
      this.calculateTotals()
    }
  }

  handleClick(event) {
    const removeButton = event.target.closest(".remove-item")
    if (!removeButton) return

    event.preventDefault()
    const item = removeButton.closest(".invoice-item")
    if (!item) return

    item.remove()
    this.renumberItems()
    this.calculateTotals()

    if (this.element.querySelectorAll("#invoice-items .invoice-item").length === 0) {
      document.getElementById("no-items")?.classList.remove("d-none")
    }
  }

  handleChange(event) {
    if (event.target.classList.contains("hs-code-field")) {
      this.loadUomForHsCode(event.target)
    }
  }

  initDatepickers() {
    if (typeof flatpickr === "undefined") return

    this.element.querySelectorAll(".datepicker").forEach((el) => {
      if (el._flatpickr) return
      flatpickr(el, {
        dateFormat: "Y-m-d",
        allowInput: true,
        altInput: true,
        altFormat: "d M Y",
        theme: "material_green"
      })
    })
  }

  destroyDatepickers() {
    this.element.querySelectorAll(".datepicker").forEach((el) => {
      el._flatpickr?.destroy()
    })
  }

  renumberItems() {
    this.element.querySelectorAll("#invoice-items .invoice-item").forEach((item, index) => {
      const badge = item.querySelector(".item-number")
      if (badge) badge.textContent = index + 1
    })
  }

  initBuyerCompanySelect() {
    const select = document.getElementById("buyer_company_select")
    const hiddenId = document.getElementById("invoice_buyer_company_id")
    if (!select || !hiddenId || select.dataset.invoiceFormBound === "true") return

    select.dataset.invoiceFormBound = "true"

    const applyCompany = (option) => {
      if (!option?.value) {
        hiddenId.value = ""
        return
      }
      hiddenId.value = option.value
      const nameEl = document.getElementById("invoice_buyer_name")
      const ntnEl = document.getElementById("invoice_buyer_ntn")
      const addressEl = document.getElementById("invoice_buyer_address")
      const provinceEl = document.getElementById("invoice_buyer_province")
      const regEl = document.getElementById("invoice_buyer_registration_type")
      if (nameEl) nameEl.value = option.dataset.name || ""
      if (ntnEl) ntnEl.value = option.dataset.ntn || ""
      if (addressEl) addressEl.value = option.dataset.address || ""
      if (provinceEl) provinceEl.value = option.dataset.province || "Punjab"
      if (regEl) regEl.value = option.dataset.registrationType || "Registered"
    }

    select.addEventListener("change", () => {
      applyCompany(select.options[select.selectedIndex])
    })

    if (select.value) {
      applyCompany(select.options[select.selectedIndex])
    } else if (hiddenId.value) {
      select.value = hiddenId.value
      applyCompany(select.options[select.selectedIndex])
    }
  }

  initInvoiceTypeToggle() {
    const invoiceTypeEl = document.getElementById("invoice_invoice_type")
    const originalField = document.getElementById("original-invoice-field")
    if (!invoiceTypeEl || !originalField || invoiceTypeEl.dataset.invoiceFormBound === "true") return

    invoiceTypeEl.dataset.invoiceFormBound = "true"
    invoiceTypeEl.addEventListener("change", () => {
      const isAdjustment = invoiceTypeEl.value === "Debit Note" || invoiceTypeEl.value === "Credit Note"
      originalField.style.display = isAdjustment ? "" : "none"
    })
  }

  initVerifyBuyer() {
    const verifyBtn = document.getElementById("verify-buyer-ntn")
    if (!verifyBtn || verifyBtn.dataset.invoiceFormBound === "true") return

    verifyBtn.dataset.invoiceFormBound = "true"
    verifyBtn.addEventListener("click", () => {
      const ntn = document.getElementById("invoice_buyer_ntn")?.value
      const statusEl = document.getElementById("buyer-ntn-status")
      if (!ntn || !statusEl) return

      statusEl.textContent = "Checking…"
      fetch("/api/v1/buyer_validations", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: JSON.stringify({ ntn })
      })
        .then((r) => r.json().then((data) => ({ ok: r.ok, data })))
        .then((res) => {
          if (!res.ok) {
            statusEl.textContent = res.data.error || "Verification failed"
            statusEl.className = "d-block small mt-1 text-danger"
            return
          }

          const label = res.data.registration_type
          const isRegistered = res.data.registered
          let msg = res.data.message || `FBR: ${label}`
          if (res.data.ntn && res.data.ntn.replace(/\D/g, "") !== ntn.replace(/\D/g, "")) {
            msg += ` (NTN normalized to ${res.data.ntn})`
          }
          statusEl.textContent = msg
          statusEl.className = `d-block small mt-1 ${isRegistered ? "text-success" : "text-warning"}`

          const regEl = document.getElementById("invoice_buyer_registration_type")
          if (regEl && label) regEl.value = label
          const ntnEl = document.getElementById("invoice_buyer_ntn")
          if (ntnEl && res.data.ntn) ntnEl.value = res.data.ntn
        })
        .catch(() => {
          statusEl.textContent = "Verification failed"
          statusEl.className = "d-block small mt-1 text-danger"
        })
    })
  }

  loadUOMForItems() {
    fetch("/api/v1/reference_data/uom", {
      headers: { Accept: "application/json", "Content-Type": "application/json" }
    })
      .then((response) => (response.ok ? response.json() : Promise.reject(response)))
      .then((data) => {
        this.element.querySelectorAll(".uom-select").forEach((select) => {
          const currentValue = select.value || select.dataset.value || ""
          if (select.options.length > 1 && !(select.options.length === 1 && select.options[0].value === "")) return

          select.innerHTML = '<option value="">Select UOM</option>'
          if (Array.isArray(data) && data.length > 0) {
            data.forEach((item) => {
              const option = document.createElement("option")
              option.value = item.description || ""
              option.textContent = item.description || ""
              select.appendChild(option)
            })
          } else {
            ["Numbers, pieces, units", "KG", "Litre", "Metre"].forEach((uom) => {
              const option = document.createElement("option")
              option.value = uom
              option.textContent = uom
              select.appendChild(option)
            })
          }
          if (currentValue) select.value = currentValue
        })
      })
      .catch((error) => console.error("Error loading UOM:", error))
  }

  loadUomForHsCode(hsField) {
    const hsCode = hsField.value
    const itemRow = hsField.closest(".invoice-item")
    const uomSelect = itemRow?.querySelector(".uom-select")
    if (!hsCode || !uomSelect) return

    fetch(`/api/v1/reference_data/hs_uom?hs_code=${encodeURIComponent(hsCode)}`)
      .then((r) => r.json())
      .then((data) => {
        if (!data?.length) return
        uomSelect.innerHTML = '<option value="">Select UOM</option>'
        data.forEach((item) => {
          const option = document.createElement("option")
          option.value = item.description
          option.textContent = item.description
          uomSelect.appendChild(option)
        })
      })
  }

  calculateItemTotal(item) {
    if (!item) return
    const quantity = parseFloat(item.querySelector(".item-quantity")?.value) || 0
    const unitPrice = parseFloat(item.querySelector(".item-unit-price")?.value) || 0
    const taxRate = parseFloat(item.querySelector(".item-tax-rate")?.value) || 0
    const totalPrice = quantity * unitPrice
    const taxAmount = totalPrice * (taxRate / 100)
    item.querySelector(".item-total-price").value = totalPrice.toFixed(2)
    item.querySelector(".item-tax-amount").value = taxAmount.toFixed(2)
  }

  calculateTotals() {
    let netAmount = 0
    let taxAmount = 0

    this.element.querySelectorAll("#invoice-items .invoice-item").forEach((item) => {
      if (item.querySelector('input[name*="_destroy"]')?.checked) return
      netAmount += parseFloat(item.querySelector(".item-total-price")?.value) || 0
      taxAmount += parseFloat(item.querySelector(".item-tax-amount")?.value) || 0
    })

    const netEl = document.getElementById("net-amount")
    const taxEl = document.getElementById("tax-amount")
    const totalEl = document.getElementById("total-amount")
    if (netEl) netEl.textContent = `Rs. ${netAmount.toFixed(2)}`
    if (taxEl) taxEl.textContent = `Rs. ${taxAmount.toFixed(2)}`
    if (totalEl) totalEl.textContent = `Rs. ${(netAmount + taxAmount).toFixed(2)}`
  }
}
