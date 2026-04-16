import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    status: String
  }

  connect() {
    this.startPolling()
  }

  disconnect() {
    this.stopPolling()
  }

  startPolling() {
    this.pollInterval = setInterval(() => {
      this.poll()
    }, 2000)
  }

  stopPolling() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
      this.pollInterval = null
    }
  }

  async poll() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-Requested-With": "XMLHttpRequest"
        },
        credentials: "same-origin"
      })

      if (!response.ok) return

      const html = await response.text()

      // Check if the response contains a terminal status
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, "text/html")

      // Look for status indicators in the turbo stream response
      const readyEl = doc.querySelector('[data-status="ready"]') ||
                      doc.querySelector('.status-ready')
      const failedEl = doc.querySelector('[data-status="failed"]') ||
                       doc.querySelector('.status-failed')

      if (readyEl || failedEl) {
        this.stopPolling()
        // Full page refresh to get the final state
        Turbo.visit(window.location.href, { action: "replace" })
        return
      }

      // Process turbo stream actions
      Turbo.renderStreamMessage(html)
    } catch (error) {
      console.error("Poll error:", error)
    }
  }
}
