import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { diff: String }

  connect() {
    if (!this.hasDiffValue || this.diffValue.trim().length === 0) {
      this.element.innerHTML = '<p class="text-gray-500 italic">No diff available.</p>'
      return
    }

    if (typeof Diff2Html === "undefined") {
      this._renderRawDiff()
      return
    }

    try {
      const diff2htmlUi = new Diff2Html.UI(
        this.element,
        this.diffValue,
        {
          drawFileList: false,
          matching: "lines",
          outputFormat: "line-by-line"
        }
      )
      diff2htmlUi.draw()
    } catch (_e) {
      this._renderRawDiff()
    }
  }

  _renderRawDiff() {
    const pre = document.createElement("pre")
    pre.className = "bg-gray-900 text-green-400 p-4 rounded overflow-auto text-sm whitespace-pre-wrap"
    pre.textContent = this.diffValue
    this.element.appendChild(pre)
  }
}
