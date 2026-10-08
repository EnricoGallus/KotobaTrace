import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="analyze-text"
export default class extends Controller {
  static targets = ["submit", "textInput"]

  start() {
    this.disableForm()
    this.submitTarget.value = "Analyzing…"
  }

  finish(event) {
    this.enableForm()
    this.submitTarget.value = "Analyze"

    if (event.detail.success) {
      console.log("Analysis succeeded")
    } else {
      console.log("Analysis failed", event.detail.fetchResponse)
    }
  }

  disableForm() {
    this.submitTarget.disabled = true
    this.textInputTarget.disabled = true
  }

  enableForm() {
    this.submitTarget.disabled = false
    this.textInputTarget.disabled = false
  }
}
