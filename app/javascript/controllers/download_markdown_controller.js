import { Controller } from "@hotwired/stimulus"

// Downloads the server-built markdown (ClarityCheck#to_markdown) as a .md file.
export default class extends Controller {
  static values = { content: String, filename: String }

  download() {
    const blob = new Blob([this.contentValue], { type: "text/markdown;charset=utf-8" })
    const url  = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href     = url
    link.download = this.filenameValue || "clarity-check.md"
    link.click()
    URL.revokeObjectURL(url)
  }
}
