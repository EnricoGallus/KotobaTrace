import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["navigation", "tab", "panel"]

  connect() {
    this.navigationTarget.hidden = false
    this.activate(this.tabTargets[0])
    this.onInvalid = (event) => {
      // Native validation fires for every invalid field. Reveal the first one
      // and keep that panel open so the browser can focus its control.
      if (this.validating) {
        event.preventDefault()
        return
      }
      const panel = event.target.closest('[data-result-tabs-target="panel"]')
      if (!panel) return
      this.validating = true
      this.activate(this.tabTargets.find((tab) => tab.getAttribute("aria-controls") === panel.id))
      this.validationTimer = setTimeout(() => { this.validating = false }, 0)
    }
    this.element.addEventListener("invalid", this.onInvalid, true)
  }

  disconnect() {
    this.element.removeEventListener("invalid", this.onInvalid, true)
    clearTimeout(this.validationTimer)
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
