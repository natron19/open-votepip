import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "overlay"]

  start() {
    this.formTargets.forEach(el => el.classList.add("d-none"))
    this.overlayTarget.classList.remove("d-none")
  }

  stop() {
    this.formTargets.forEach(el => el.classList.remove("d-none"))
    this.overlayTarget.classList.add("d-none")
  }
}
