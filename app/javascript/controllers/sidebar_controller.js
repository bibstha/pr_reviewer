import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  scrollToFile(event) {
    event.preventDefault()
    const filePath = event.currentTarget.dataset.filePath
    const target = document.querySelector(`[data-file-path="${filePath}"]`)

    if (target) {
      target.scrollIntoView({ behavior: "smooth", block: "start" })

      // Highlight active file in sidebar
      document.querySelectorAll(".reading-order a").forEach(a => a.classList.remove("active"))
      event.currentTarget.classList.add("active")
    }
  }
}
