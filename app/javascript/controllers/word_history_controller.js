import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "frame", "errorTemplate"]
  static values = { loading: String }

  open(event) {
    this.frameTarget.textContent = this.loadingValue
    this.frameTarget.removeAttribute("src")
    this.frameTarget.src = event.currentTarget.dataset.wordHistoryUrl
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  failed(event) {
    event.preventDefault()
    this.frameTarget.replaceChildren(this.errorTemplateTarget.content.cloneNode(true))
  }

  reload() {
    this.frameTarget.textContent = this.loadingValue
    this.frameTarget.reload()
  }

  formatDates() {
    this.frameTarget.querySelectorAll("time[datetime]").forEach((time) => {
      time.textContent = new Date(time.dateTime).toLocaleString(document.documentElement.lang, {
        dateStyle: "medium", timeStyle: "short"
      })
    })
  }
}
