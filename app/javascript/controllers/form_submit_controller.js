import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.element.addEventListener("turbo:submit-end", (e) => {
      if (!e.detail.success) this.enable()
    })
  }

  disable() {
    const btn = this.hasButtonTarget ? this.buttonTarget : this.element.querySelector("[type=submit]")
    if (!btn) return
    btn.dataset.originalText = btn.value || btn.textContent
    btn.disabled = true
    if (btn.tagName === "INPUT") {
      btn.value = "Saving…"
    } else {
      btn.textContent = "Saving…"
    }
  }

  enable() {
    const btn = this.hasButtonTarget ? this.buttonTarget : this.element.querySelector("[type=submit]")
    if (!btn) return
    btn.disabled = false
    const original = btn.dataset.originalText
    if (btn.tagName === "INPUT") {
      btn.value = original || "Submit"
    } else {
      btn.textContent = original || "Submit"
    }
  }
}
