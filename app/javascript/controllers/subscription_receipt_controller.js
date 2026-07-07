import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["months", "monthlyFee", "activeUntil", "extraLines", "total", "lineTemplate"]
  static values = {
    baseDate: String
  }

  connect() {
    this.recalculate()
  }

  recalculate() {
    const months = Math.max(parseInt(this.monthsTarget.value, 10) || 0, 0)
    const monthlyFee = parseFloat(this.monthlyFeeTarget.value) || 0
    const subscriptionTotal = months * monthlyFee
    let extrasTotal = 0

    this.extraLinesTarget.querySelectorAll("[data-line-amount]").forEach((input) => {
      extrasTotal += parseFloat(input.value) || 0
    })

    if (months > 0 && this.baseDateValue) {
      const base = new Date(`${this.baseDateValue}T00:00:00`)
      base.setMonth(base.getMonth() + months)
      this.activeUntilTarget.value = this.formatDate(base)
    }

    this.totalTarget.textContent = this.formatCurrency(subscriptionTotal + extrasTotal)
  }

  addLine(event) {
    event.preventDefault()
    const content = this.lineTemplateTarget.content.cloneNode(true)
    this.extraLinesTarget.appendChild(content)
    this.recalculate()
  }

  removeLine(event) {
    event.preventDefault()
    const row = event.target.closest("[data-line-row]")
    if (row) row.remove()
    this.recalculate()
  }

  formatDate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, "0")
    const day = String(date.getDate()).padStart(2, "0")
    return `${year}-${month}-${day}`
  }

  formatCurrency(amount) {
    return `Rs. ${amount.toFixed(2)}`
  }
}
