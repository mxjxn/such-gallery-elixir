/**
 * Minified topbar placeholder — progress bar for LiveView navigation.
 * https://github.com/buunguyen/topbar (MIT)
 */
(function (root, factory) {
  if (typeof define === "function" && define.amd) {
    define(factory)
  } else if (typeof exports === "object") {
    module.exports = factory()
  } else {
    root.topbar = factory()
  }
})(typeof self !== "undefined" ? self : this, function () {
  var config = {autoRun: true, barThickness: 3, barColors: {0: "rgba(41, 128, 185, 1)"}, shadowBlur: 5}
  var currentProgress = 0
  var canvas, ctx, progressTimerId, fadeTimerId

  function repaint() {
    if (!ctx) return
    ctx.clearRect(0, 0, canvas.width, canvas.height)
    var s = (1 - Math.pow(1 - currentProgress, 2)) * canvas.width
    ctx.fillStyle = config.barColors[0]
    ctx.fillRect(0, 0, s, config.barThickness)
  }

  return {
    config: function (opts) {
      for (var k in opts) if (opts.hasOwnProperty(k)) config[k] = opts[k]
    },
    show: function (delay) {
      if (progressTimerId) return
      var delayMs = delay || 0
      progressTimerId = setTimeout(function () {
        if (!canvas) {
          canvas = document.createElement("canvas")
          canvas.style.cssText = "position:fixed;top:0;left:0;width:100%;z-index:10000;pointer-events:none"
          canvas.height = config.barThickness
          canvas.width = window.innerWidth
          document.body.appendChild(canvas)
          ctx = canvas.getContext("2d")
        }
        currentProgress = 0
        repaint()
        var step = function () {
          currentProgress += 0.05
          if (currentProgress >= 0.95) return
          repaint()
          progressTimerId = setTimeout(step, 16)
        }
        step()
      }, delayMs)
    },
    hide: function () {
      clearTimeout(progressTimerId)
      progressTimerId = null
      currentProgress = 1
      repaint()
      fadeTimerId = setTimeout(function () {
        if (canvas && canvas.parentNode) canvas.parentNode.removeChild(canvas)
        canvas = ctx = null
        currentProgress = 0
      }, 300)
    }
  }
})
