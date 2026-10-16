import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "controls", "submit", "textInput", "requestId", "results", "progress", "errorTemplate", "completion", "bulkAssessment", "assessment"]
  static values = { progressLabel: String }

  prepare(event) {
    if (this.pending) {
      event.preventDefault()
      return
    }

    // getRandomValues also works for local HTTP development origins.
    this.requestIdTarget.value = crypto.getRandomValues(new Uint32Array(4)).join("-")
    this.resultsTarget.replaceChildren()
  }

  start() {
    this.pending = true
    this.submitLabel = this.submitTarget.value
    this.showProgress()
  }

  submissionFinished(event) {
    // Turbo's submit-end only acknowledges enqueueing, not job completion.
    if (!this.pending) return

    if (event.detail.success) {
      this.showProgress()
    } else {
      // Validation/enqueue errors supply their own terminal Turbo Stream.
      if (!event.detail.fetchResponse?.contentType?.includes("text/vnd.turbo-stream.html")) {
        this.requestFailed()
      }
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
    if (requestId && (!this.pending || requestId !== this.requestIdTarget.value)) {
      event.preventDefault()
    }
  }

  requestFailed() {
    if (!this.pending) return
    this.resultsTarget.replaceChildren(this.errorTemplateTarget.content.cloneNode(true))
    this.finish()
  }

  finish() {
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
