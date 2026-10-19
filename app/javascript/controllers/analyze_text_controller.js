import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "controls", "submit", "textInput", "requestId", "results", "progress", "errorTemplate", "connectionErrorTemplate", "completion", "bulkAssessment", "assessment"]
  static values = { progressLabel: String, connectingLabel: String, timeout: { type: Number, default: 600000 }, connectionTimeout: { type: Number, default: 30000 } }

  disconnect() {
    clearTimeout(this.completionTimeout)
    clearTimeout(this.connectionTimeout)
    this.connectionObserver?.disconnect()
  }

  prepare(event) {
    if (this.pending) {
      event.preventDefault()
      return
    }

    // Broadcasts sent before the subscription connects are lost.
    if (!this.element.querySelector("turbo-cable-stream-source[connected]")) {
      event.preventDefault()
      this.waitForConnection()
      return
    }

    // getRandomValues also works for local HTTP development origins.
    this.requestIdTarget.value = crypto.getRandomValues(new Uint32Array(4)).join("-")
    this.resultsTarget.replaceChildren()
  }

  waitForConnection() {
    this.pending = true
    this.submitLabel = this.submitTarget.value
    this.showProgress()
    this.submitTarget.value = this.connectingLabelValue
    this.progressTarget.textContent = this.connectingLabelValue

    this.connectionObserver = new MutationObserver(() => {
      if (!this.element.querySelector("turbo-cable-stream-source[connected]")) return
      this.finish()
      this.formTarget.requestSubmit(this.submitTarget)
    })
    this.connectionObserver.observe(this.element, {
      subtree: true, childList: true, attributes: true, attributeFilter: ["connected"]
    })
    this.connectionTimeout = setTimeout(() => {
      this.resultsTarget.replaceChildren(this.connectionErrorTemplateTarget.content.cloneNode(true))
      this.finish()
    }, this.connectionTimeoutValue)
  }

  start() {
    this.pending = true
    this.submitLabel = this.submitTarget.value
    this.showProgress()
    this.completionTimeout = setTimeout(() => this.requestFailed(), this.timeoutValue)
  }

  submissionFinished(event) {
    if (!this.pending) return
    // Turbo clears aria-busy and restores the button after enqueueing.
    // Keep the job's progress state until its completion arrives.
    this.showProgress()
    if (!event.detail.success &&
        !event.detail.fetchResponse?.contentType?.includes("text/vnd.turbo-stream.html")) {
      this.requestFailed()
    }
  }

  showProgress() {
    this.controlsTarget.disabled = true
    this.formTarget.setAttribute("aria-busy", "true")
    this.progressTarget.hidden = false
    this.submitTarget.value = this.progressLabelValue
  }

  completionTargetConnected(element) {
    if (element.dataset.analysisRequestId !== this.requestIdTarget.value) return
    this.finish()
  }

  filterStream(event) {
    if (event.target.getAttribute("target") !== this.resultsTarget.id) return

    const completion = event.target.templateElement.content.querySelector("[data-analysis-request-id]")
    const requestId = completion?.dataset.analysisRequestId
    // Save-validation responses have no request ID and must remain renderable.
    // A timeout only unlocks the form. The current job may still finish later.
    if (requestId && requestId !== this.requestIdTarget.value) {
      event.preventDefault()
    }
  }

  requestFailed() {
    if (!this.pending) return
    this.resultsTarget.replaceChildren(this.errorTemplateTarget.content.cloneNode(true))
    this.finish()
  }

  finish() {
    clearTimeout(this.completionTimeout)
    clearTimeout(this.connectionTimeout)
    this.connectionObserver?.disconnect()
    this.progressTarget.textContent = this.progressLabelValue
    this.pending = false
    this.controlsTarget.disabled = false
    this.formTarget.setAttribute("aria-busy", "false")
    this.progressTarget.hidden = true
    if (this.submitLabel) this.submitTarget.value = this.submitLabel
  }

  applyAssessmentToUnselected() {
    const value = this.bulkAssessmentTarget.value
    if (!value) return

    this.assessmentTargets.forEach((select) => {
      if (!select.value) select.value = value
    })
  }

  retry() {
    this.formTarget.requestSubmit(this.submitTarget)
  }
}
