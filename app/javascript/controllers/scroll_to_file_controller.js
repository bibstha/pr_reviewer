import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  connect() {
    this._observer = new IntersectionObserver(
      (entries) => this._highlightVisibleFile(entries),
      { rootMargin: "-10% 0px -80% 0px" }
    )

    // Observe diff file sections after a short delay to allow diff2html rendering
    setTimeout(() => this._observeDiffSections(), 500)
  }

  disconnect() {
    if (this._observer) this._observer.disconnect()
  }

  scrollTo(event) {
    event.preventDefault()
    const filePath = event.currentTarget.dataset.filePath
    if (!filePath) return

    const target = this._findDiffSection(filePath)
    if (target) {
      target.scrollIntoView({ behavior: "smooth", block: "start" })
      this._setActiveLink(event.currentTarget)
    }
  }

  _findDiffSection(filePath) {
    // diff2html wraps each file in a .d2h-file-wrapper with a .d2h-file-name-header
    const wrappers = document.querySelectorAll(".d2h-file-wrapper")
    for (const wrapper of wrappers) {
      const nameEl = wrapper.querySelector(".d2h-file-name")
      if (nameEl) {
        // diff2html may show "a/path → b/path" for renames, or just the filename
        const name = nameEl.textContent.trim()
        if (name === filePath || name.endsWith("/" + filePath) || name.endsWith(filePath)) {
          return wrapper
        }
      }
    }
    return null
  }

  _setActiveLink(activeLink) {
    this.linkTargets.forEach(link => link.classList.remove("active", "font-bold", "text-blue-400"))
    activeLink.classList.add("active", "font-bold", "text-blue-400")
  }

  _observeDiffSections() {
    document.querySelectorAll(".d2h-file-wrapper").forEach(section => {
      this._observer.observe(section)
    })
  }

  _highlightVisibleFile(entries) {
    for (const entry of entries) {
      if (entry.isIntersecting) {
        const nameEl = entry.target.querySelector(".d2h-file-name")
        if (!nameEl) continue
        const fileName = nameEl.textContent.trim()
        const matchingLink = this.linkTargets.find(link => {
          const fp = link.dataset.filePath
          return fp && (fileName === fp || fileName.endsWith("/" + fp) || fileName.endsWith(fp))
        })
        if (matchingLink) this._setActiveLink(matchingLink)
      }
    }
  }
}
