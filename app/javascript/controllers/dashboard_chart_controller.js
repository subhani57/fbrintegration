import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values = {
    labels: Array,
    values: Array
  }

  connect() {
    if (!this.hasCanvasTarget || typeof Chart === "undefined") return

    this.chart = new Chart(this.canvasTarget.getContext("2d"), {
      type: "line",
      data: {
        labels: this.labelsValue,
        datasets: [{
          label: "Invoice amount (Rs.)",
          data: this.valuesValue,
          borderColor: "#157347",
          backgroundColor: "rgba(21, 115, 71, 0.12)",
          borderWidth: 2,
          fill: true,
          tension: 0.35,
          pointRadius: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (ctx) => {
                const amount = Number(ctx.parsed.y).toLocaleString("en-PK", {
                  minimumFractionDigits: 2,
                  maximumFractionDigits: 2
                })
                return `Rs. ${amount}`
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              callback: (value) => `Rs. ${Number(value).toLocaleString("en-PK")}`
            }
          }
        }
      }
    })
  }

  disconnect() {
    this.chart?.destroy()
    this.chart = null
  }
}
