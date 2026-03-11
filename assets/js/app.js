// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/pulse"
import topbar from "../vendor/topbar"
import { domToBlob } from "modern-screenshot"

async function capturePortfolio(target) {
  target.classList.add("capture-mode")

  // Wait one frame for layout to settle
  await new Promise(r => requestAnimationFrame(r))

  try {
    const bg = getComputedStyle(target).backgroundColor
    const blob = await domToBlob(target, { scale: 2, backgroundColor: bg })
    return new File([blob], "portfolio.png", { type: "image/png" })
  } finally {
    target.classList.remove("capture-mode")
  }
}

const SaveImage = {
  mounted() {
    this.el.addEventListener("click", async () => {
      const label = this.el.querySelector("[data-label]")
      const defaultLabel = this.el.dataset.labelDefault || "Save Image"
      const capturingLabel = this.el.dataset.labelCapturing || "Capturing..."
      const savedLabel = this.el.dataset.labelSaved || "Saved!"
      const failedLabel = this.el.dataset.labelFailed || "Failed"
      const setLabel = (msg) => { if (label) label.textContent = msg }
      const target = document.getElementById("portfolio-capture")
      if (!target) return

      setLabel(capturingLabel)

      try {
        const file = await capturePortfolio(target)

        // Try native share with image (works on most mobile browsers)
        if (navigator.canShare && navigator.canShare({ files: [file] })) {
          await navigator.share({ files: [file] })
          setLabel(defaultLabel)
          return
        }

        // Desktop fallback: download via anchor click
        const a = document.createElement("a")
        a.href = URL.createObjectURL(file)
        a.download = "portfolio.png"
        a.click()
        URL.revokeObjectURL(a.href)
        setLabel(savedLabel)
        setTimeout(() => setLabel(defaultLabel), 2000)
      } catch (e) {
        if (e.name === "AbortError") { setLabel(defaultLabel); return }
        console.error("SaveImage failed:", e, e.stack)
        setLabel(failedLabel)
        setTimeout(() => setLabel(defaultLabel), 2000)
      }
    })
  }
}

const ShareLink = {
  mounted() {
    this.el.addEventListener("click", async () => {
      const url = this.el.dataset.url
      const title = this.el.dataset.title
      const text = this.el.dataset.text
      const label = this.el.querySelector("[data-label]")
      const defaultLabel = this.el.dataset.labelDefault || "Share Link"
      const capturingLabel = this.el.dataset.labelCapturing || "Capturing..."
      const copiedLabel = this.el.dataset.labelCopied || "Copied!"
      const setLabel = (msg) => { if (label) label.textContent = msg }
      const target = document.getElementById("portfolio-capture")

      if (target) {
        setLabel(capturingLabel)
        try {
          const file = await capturePortfolio(target)

          if (navigator.canShare && navigator.canShare({ files: [file] })) {
            await navigator.share({ files: [file], title, text, url })
            setLabel(defaultLabel)
            return
          }
        } catch (e) {
          if (e.name === "AbortError") { setLabel(defaultLabel); return }
        }
      }

      // Fallback: share URL or copy to clipboard
      if (navigator.share) {
        try {
          await navigator.share({ url, title, text })
        } catch (_e) { /* user cancelled */ }
      } else {
        await navigator.clipboard.writeText(url)
        setLabel(copiedLabel)
        setTimeout(() => setLabel(defaultLabel), 2000)
        return
      }
      setLabel(defaultLabel)
    })
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const locale = localStorage.getItem("pulse-lang") || document.documentElement.lang || "en"
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken, locale: locale},
  hooks: {...colocatedHooks, SaveImage, ShareLink},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

