import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["navigation", "tab", "panel", "remaining", "validation"]
  static values = { remainingLabel: String }

  connect() {
    this.navigationTarget.hidden = false
    this.activate(this.tabTargets[0])
    this.update()
    this.onInvalid = (event) => {
      // Keep the user's tab in place; summarize missing choices across both tabs.
      event.preventDefault()
      this.attempted = true
      this.update()
      this.validationTarget.focus()
    }
    this.element.addEventListener("invalid", this.onInvalid, true)
  }

  disconnect() {
    this.element.removeEventListener("invalid", this.onInvalid, true)
  }

  update() {
    let totalMissing = 0
    this.panelTargets.forEach((panel) => {
      const fields = Array.from(panel.querySelectorAll("select[required]"))
      const missing = fields.filter((field) => !field.value).length
      totalMissing += missing
      const label = this.remainingTargets.find((element) => element.dataset.panel === panel.id)
      label.textContent = this.remainingLabelValue.replace("{count}", missing)
      label.hidden = missing === 0
      fields.forEach((field) => {
        if (this.attempted && !field.value) field.setAttribute("aria-invalid", "true")
        else field.removeAttribute("aria-invalid")
      })
    })
    this.validationTarget.hidden = !this.attempted || totalMissing === 0
  }

  select(event) {
    this.activate(event.currentTarget)
  }

  navigate(event) {
    const tabs = this.tabTargets
    const index = tabs.indexOf(event.currentTarget)
    let next
    switch (event.key) {
      case "ArrowRight": next = (index + 1) % tabs.length; break
      case "ArrowLeft": next = (index - 1 + tabs.length) % tabs.length; break
      case "Home": next = 0; break
      case "End": next = tabs.length - 1; break
      default: return
    }
    event.preventDefault()
    this.activate(tabs[next])
    tabs[next].focus()
  }

  activate(selected) {
    if (!selected) return
    this.tabTargets.forEach((tab) => {
      const active = tab === selected
      tab.setAttribute("aria-selected", String(active))
      tab.tabIndex = active ? 0 : -1
    })
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.id !== selected.getAttribute("aria-controls")
    })
  }
}
