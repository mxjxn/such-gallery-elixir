import {Socket} from "phoenix"

// SIWE wallet authentication
// Requires: window.ethereum (injected by MetaMask or similar)

const SIWE_DOMAIN = window.location.host
const SIWE_ORIGIN = window.location.origin
const SIWE_STATE_KEY = "suchgallery_siwe_state"

// --- EIP-6963 Provider Discovery ---
const providers = new Map()
let selectedProvider = null

// Announce a provider
function announceProvider(event) {
  const { info, provider } = event.detail
  if (!providers.has(info.uuid)) {
    providers.set(info.uuid, { info, provider })
    // Re-render the button if the UI is already initialized
    if (document.getElementById("wallet-btn-inner")) {
        const btn = document.getElementById("wallet-btn-inner")
        if (!getState()) { // only re-render if we are logged out
            renderLoggedOut(btn)
        }
    }
  }
}

// Listen for wallets to announce themselves
window.addEventListener("eip6963:announceProvider", announceProvider)

// Request providers
window.dispatchEvent(new Event("eip6963:requestProvider"))

// Fallback to window.ethereum if no EIP-6963 providers are found after a short delay
setTimeout(() => {
    if (providers.size === 0 && typeof window.ethereum !== 'undefined') {
        const info = {
            uuid: 'io.metamask', // Generic UUID for window.ethereum
            name: 'MetaMask',
            icon: 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjU2IiBoZWlnaHQ9IjI1NiIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cGF0aCBkPSJNMjUwLjU3MiAyMDkuNTNjLTEuODQ4LTMuNTAzLTQuOTcxLTYuMDM1LTguODEzLTYuODM4bC0yMC4xMzQtMi4yOWMtMi4wMzQtLjIzMy0zLjkzMS0xLjA4Mi01LjM1OC0yLjQxN2wtMTUuOTkyLTE0LjI0Yy0uMi0uMTc3LS4zOTUtLjM1OC0uNTg3LS41NDZsLTIuMDc5LTIuMDMzYy0uNTc0LS41NjEtMS4zMjUtLjkxLTEuOTY0LTEuMzA0aDBsLTIwLjI2My0xMi4yMDVjLTUuNjctMy4zOTYtMTIuNjQyLTMuMzk2LTE4LjMxNiAwbC0xOS4zNTggMTEuNjE2Yy0uNjM5LjM5My0xLjM5Ljc0Mi0xLjk2MyAxLjMwNWwtMi4wOCAyLjAzM2MtLjE5Mi4xODgtLjM4Ny4zNjktLjU4Ny41NDZsLTE1Ljk5MiAxNC4yNGMtMS40MjcgMS4zMzUtMy4zMjQgMi4xODQtNS4zNTggMi40MTdsLTIwLjEzNCAyLjI5Yy0zLjgzMi40MzctNi45NjYgMi45NzEtOC44MTMgNi44MzgtMi4xOSA0LjYxNC0uNTcgOS45MjcgNC4wNDMgMTIuMTIybDE4LjU1IDEwLjUxMmMxLjIzOS43IDIuNTIgMS4yOTcgMy43MDQgMS44OTFsMTkuMjg2IDkuMDc0YzEuMjc4LjYwMiAyLjU4OC45MDYgMy44OTYuOTA2aDBjMS4zMDggMCAyLjYxOC0uMzA0IDMuODk2LS45MDZsMTkuMjg2LTkuMDc0YzEuMTg0LS41OTQgMi40NjUtMS4xOTEgMy43MDQtMS44OWwxOC41NS0xMC41MTJjNC42MTMtMi4xOTUgNS43LTYuOTcyIDQuMDQzLTEyLjEyMnptLTk3LjQyMy02Mi43NDRsMTYuMzU0IDE0LjU2MmMyLjYxMSAyLjM3MyA0LjM2MSAzLjI2OCA0LjM2MSA0LjQ0N3YyMi4xMDFjMCA1LjM2NC0yLjg4MyA4LjczNS02Ljk5NyA4LjczNWgtLjM0MmMtNC4xMTUgMC02Ljk5Ny0zLjM3MS02Ljk5Ny04LjczNXYtMTQuNDQ1YzAtNC4zNDMtMS43Mi02LjM4OS00LjY4OC04LjMyM2wtMTUuNjM5LTEzLjg1OGMtMi45NjgtMi42NDItNC42ODctNC43MzYtNC42ODctOC4zMjN2LTEzLjM0YzAtNC4xMTIgMy4xNjMtOC40ODUgNy4yNDctOC40ODVoLjQ1NGM0LjA4MyAwIDcuMjQ3IDQuMzcyIDcuMjQ7IDguNDg1djEzLjM0YzAgMy41ODgtMS43MiA1LjY4Mi00LjY4NyA4LjMyM3ptLTM0LjU2MyA3LjQ5NWMtMi45NjgtMi42NDItNC42ODctNC43MzYtNC42ODctOC4zMjN2LTEzLjM0YzAtNC4xMTIgMy4xNjMtOC40ODUgNy4yNDctOC40ODVoLjQ1NGM0LjA4MyAwIDcuMjQ2IDQuMzcyIDcuMjQ2IDguNDg1djEzLjM0YzAgMy41ODgtMS43MTkgNS42ODItNC42ODcgOC4zMjNsLTE1LjYzOSAxMy44NThjLTIuOTY4IDIuNjQtNC42ODggNC42ODctNC42ODggOC4zMjN2MTQuNDQ1YzAgNS4zNjQtMi44ODMgOC43MzUtNi45OTcgOC43MzVoLS4zNDJjLTQuMTE0IDAtNi45OTctMy4zNzEtNi45OTctOC43MzV2LTIyLjFjMC0xLjE3OSAxLjc1MS0yLjA3NSA0LjM2Mi00LjQ0N2wxNi4zNTItMTQuNTYyem0xNDIuNzIgNDIuNzQ4bC05LjU3IDEwLjg2N2MtMS40NjggMS42Ni0zLjQ4OCAyLjYxNy01LjYzMyAyLjYxN2gtMjguMTk4Yy0yLjE0NSAwLTQuMTY1LS45NTctNS42MzQtMi42MTdsLTkuNTY5LTEwLjg2N2MtMS40NjktMS42Ni0yLjI3OS0zLjcyMS0yLjI3OS01Ljg0N3YtMjEuOTg2YzAtNC41MyAzLjQxMy04LjE4NiA3LjYyNy04LjE4NmgyOC43NDNjNC4yMTMgMCA3LjYyNyAzLjY1NiA3LjYyNyA4LjE4NnYyMS45ODZjMCAyLjEyNi0uODEgNC4xODYtMi4yNzUgNS44NDd6bS0yNC4zMjEtNDQuOTQyaC0uMzQyYy0xLjI4OSAwLTIuMTM5LS43OC0yLjEzOS0yLjAzN3YtOS4xOGMwLTEuMjU4Ljg1LTEuNzQ3IDIuMTM5LTEuNzQ3aC4zNDJjMS4yODkgMCAyLjEzOS40ODkgMi4xMzkgMS43NDd2OS4xOGMwIDEuMjU4LS44NSAyLjAzNy0yLjEzOSAyLjAzN3oiIGZpbGw9IiNmNjguNTJkIi8+PHBhdGggZD0iTTIwOS41NDkgMTg4LjY2OGwxNi4zNTIgMTQuNTYyYzIuNjExIDIuMzcyIDQuMzYxIDMuMjY4IDQuMzYxIDQuNDQ3djEzLjM0YzAgNC4xMTMtMy4xNjQgOC40ODUtNy4yNDYgOC40ODVoLS40NTRjLTQuMDgzIDAtNy4yNDctNC4zNzItNy4yNDctOC40ODV2LTEzLjM0YzAgLTMuNTg3IDEuNzItNS42ODIgNC42ODgtOC4zMjNsMTUuNjM4LTEzLjg1OGMyLjk2OC0yLjY0IDQuNjg4LTQuNzM1IDQuNjg4LTguMzIydi0xNC40NDZjMC01LjM2MyAyLjg4My04LjczNSA2Ljk5Ny04LjczNWguMzQyYzQuMTE1IDAgNi45OTcgMy4zNzIgNi45OTcgOC43MzV2MjIuMTAxYzAgMS4xNzgtMS43NSAyLjA3NC00LjM2MiA0LjQ0N3ptLTY5LjEyNS0yMS4yMzVjMi45NjggMi42MzkgNC42ODcgNC43MzUgNC42ODcgOC4zMjN2MTMuMzRjMCA0LjExMy0zLjE2MyA4LjQ4NS03LjI0NiA4LjQ4NWgtLjQ1NGMtNC4wODQgMC03LjI0Ny00LjM3Mi03LjI0Ny04LjQ4NXYtMTMuMzRjMC0zLjU4NyAxLjcyLTUuNjgyIDQuNjg4LTguMzIzbDE1LjYzOC0xMy44NThjMi45NjgtMi42NCA0LjY4OC00LjY4NyA0LjY4OC04LjMyM3YtMTQuNDQ2YzAtNS4zNjMgMi44ODMtOC43MzUgNi45OTctOC43MzVoLjM0MmM0LjExNSAwIDYuOTk3IDMuMzcyIDYuOTk3IDguNzM1diAyMi4xYzAgMS4xNzktMS43NSAyLjA3NS00LjM2MiA0LjQ0N2wtMTYuMzUzIDE0LjU2MnoiIGZpbGw9IiNmNjguNTJkIi8+PHBhdGggZD0iTTIzNy4zNjEgMTE0LjE2OGwtMTYuODM1IDkuNDAxYy0uNTI5LjMwOS0xLjA3Mi41OTYtMS42MS44NzRsLTE4LjgxMyAxMC4yOTRjLTIuMTg5IDEuMjIzLTMuMzU5IDEuODQyLTQuNTM5IDEuODQyaC0uMDAyYy0xLjE4IDAtMi4zNDktLjYxOS00LjUzOC0xLjg0MmwtMTguODEzLTEwLjI5NGMtLjUzMS0uMjc4LTEuMDgzLS41NjUtMS42MTMtLjg3NGwtMTYuODM3LTkuNDAxYy0yLjM5OC0xLjQwMy0zLjgxMy0zLjc4MS0zLjgxMy02LjI3N3YtMTkuNDI4YzAtNC4zNDYgMy4xNTItOS4xODggNy4xMzEtOS4xODhoLjQ1NGM0LjA4MyAwIDcuMjQ3IDQuNTUgNy4yNDcgOS4xODh2MTkuNDI4YzAgMS4zMy41NzUgMi40MTIgMS41OTIgMy4wN2wxNi43NDIgOS4yNTVjMS4wMTcuNjYgMi4wMzUgMS4yMyAyLjk0MyAxLjIzaC4wMDJjLjkwOCAwIDEuOTI2LS41NyAyLjk0My0xLjIzbDE2Ljc0My05LjI1NWMxLjAxNS0uNjU4IDEuNTktMS43NCAxLjU5LTMuMDd2LTE5LjQyOGMwLTQuNjM4IDMuMTY0LTkuMTg4IDcuMjQ3LTkuMTg4aC40NTRjMy45NzkgMCA3LjEzMSA0LjgzMiA3LjEzMSA5LjE4OHYxOS40MjhjLjAwMiAyLjQ5Ni0xLjQxMyA0Ljg3NC0zLjgxMyA2LjI3N3ptLTgxLjQ0OCAxMS4wNTVjLTIuODg0IDAtNi45OTgtMy4zNzItNi45OTgtOC43MzV2LTEyLjM0MWMwLTIuNTI0IDEuMjYyLTMuNjUyIDMuMzMyLTQuODczbDE5LjU1MS0xMS4yMTVjMi4wNy0xLjU1MiAzLjAwMy0yLjczMiAzLjI1LTMuNTgydi0xNS41MmMwLTUuNDExIDIuODMyLTguODM1IDYuODM3LTguODM1aC4zNDJjMy44OTQgMCA2LjgzNyAzLjQyNCA2LjgzNyA4LjAzNnYxNS41MmMwIDEuMjEzIDEuMDM5IDIuNTE3IDMuMjQ4IDMuNTgybDE5LjU1MiAxMS4yMTZjMi4wNjkgMS4yMiAzLjMyOSAyLjM0NiAzLjMyOSA0Ljg3MXYxMi4zNDFjMCA1LjM2My00LjExNSA4LjczNS02Ljk5OCA4LjczNWgtLjM0MmMtMy45MjYgMC02Ljk5OC0zLjM3Mi02Ljk5OC04LjczNXYtMTIuMjRjMC0uOC0uMzctMS4xMzYtLjk2LTEuNDg5bC0xOS4yNjMtMTEuMTM4Yy0uNTg3LS41NDYtMS4xMTctLjgxNi0xLjgyLS44MTZoLS4wMDNjLS43MDMgMC0xLjIzMy4yNy0xLjgxOS44MTZsLTE5LjI2NCAxMS4xMzdjLS41ODkuMzUzLS45NjEuNjg5LS45NjEgMS40OXYxMi4yNGMwIDUuMzYzLTMuMDcyIDguNzM1LTYuOTk4IDguNzM1aC0uMzQxek0xMjcuNzI3IDBjLTQuMDgzIDAtNy4yNDYgNC4zNzItNy4yNDYgOC40ODV2OC4zMjNjMCAzLjU4OC0xLjcyIDUuNjgyLTQuNjg4IDguMzIzbC0xNS42MzggMTMuODU4Yy0yLjk2OCAyLjY0LTQuNjg4IDQuNjg4LTQuNjg4IDguMzIzdi41NjdjMCAxLjE3OC4zNDIgMi4zMDQgMS4wMjggMy4yNDVsMTAuNjQ0IDExLjkwOGMyLjA3IDEuNzgzIDQuNDU0IDIuODM2IDcuMDMyIDIuODM2aDI2LjM2NWMzLjE5NiAwIDUuODQ4LTEuNDE5IDcuNTM4LTMuMzk1bDEwLjEwMS0xMS4zMjJjLjU0Mi0uNjQxLjg0My0xLjQzMi44NDMtMi4yODV2LS41NjdjMC0zLjYzNS0xLjcyLTUuNjgzLTQuNjg4LTguMzIzbC0xNS42MzgtMTMuODU4Yy0yLjk2OC0yLjY0MS00LjY4OC00LjcyMS00LjY4OC04LjMyM3YtOC4zMjNjMC00LjExMy0zLjE2My04LjQ4NS03LjI0Ni04LjQ4NWgtLjQ1NHptLTE5Ljg1NCA0Ny4zMDdoLS4zNDJjLTEuMjg5IDAtMi4xMzktLjc4LTIuMTM5LTIuMDM3di05LjE4YzAtMS4yNTguODUtMS43NDcgMi4xMzktMS43NDdoLjM0MmMxLjI4OSAwIDIuMTM5LjQ4OSAyLjEzOSAxLjc0N3Y5LjE4YzAgMS4yNTgtLjg1IDIuMDM3LTIuMTM5IDIuMDM3em0yMS40MzggMGgtLjM0MmMtMS4yODkgMC0yLjEzOS0uNzgtMi4xMzktMi4wMzd2LTkuMThjMC0xLjI1OC44NS0xLjc0NyAyLjEzOS0xLjc0N2guMzQyYzEuMjg5IDAgMi4xMzkuNDg5IDIuMTM5IDEuNzQ3djkuMThjMCAxLjI1OC0uODUgMi4wMzctMi4xMzkgMi4wMzd6IiBmaWxsPSIjZTE3NzI3Ii8+PHBhdGggZD0iTTc5Ljc3MSA3Mi4wNjJjMCAzLjU4OC0xLjcyIDUuNjgyLTQuNjg4IDguMzIzbC0xNS42MzggMTMuODU4Yy0yLjk2OCAyLjY0LTQuNjg3IDQuNjg4LTQuNjg3IDguMzIzdi41NjdjMCAuODUzLjI5OSAxLjY0NC44NDEgMi4yODVsMTAuMDkgMTEuMzIyYzEuNjkxIDEuOTc2IDQuMzQyIDMuMzk1IDcuNTM4IDMuMzk1aDI2LjM2NWMyLjU3NyAwIDQuOTYyLTEuMDUzIDcuMDMyLTIuODM2bDEwLjY0NC0xMS45MDhjLjY4Ni0uOTQxIDEuMDI4LTIuMDY3IDEuMDI4LTMuMjQ1di0uNTY3YzAtMy42MzUtMS43Mi01LjY4My00LjY4OC04LjMyM2wtMTUuNjM4LTEzLjg1OGMtMi45NjgtMi42NDEtNC42ODgtNC43MjEtNC42ODgtOC4zMjN2LTguMzIzYzAtNC4xMTMtMy4xNjQtOC40ODUtNy4yNDctOC40ODVoLS40NTRjLTQuMDgzIDAtNy4yNDYgNC4zNzItNy4yNDYgOC40ODV2OC4zMjN6bTI3LjU2NyAyOC43MjJoLS4zNDJjLTEuMjg5IDAtMi4xMzktLjc4LTIuMTM5LTIuMDM3di05LjE4YzAtMS4yNTguODUtMS43NDcgMi4xMzktMS43NDdoLjM0MmMxLjI4OSAwIDIuMTM5LjQ4OSAyLjEzOSAxLjc0N3Y5LjE4YzAgMS4yNTgtLjg1IDIuMDM3LTIuMTM5IDIuMDM3em0tMjEuNDM4IDBoLS4zNDJjLTEuMjg5IDAtMi4xMzktLjc4LTIuMTM5LTIuMDM3di05LjE4YzAtMS4yNTguODUtMS47NDcgMi4xMzktMS43NDdoLjM0MmMxLjI4OSAwIDIuMTM5LjQ4OSAyLjEzOSAxLjc0N3Y5LjE4YzAgMS4yNTgtLjg1IDIuMDM3LTIuMTM5IDIuMDM3eiIgZmlsbD0iI2Q5NGIzMiIvPjxwYXRoIGQ9Ik0xNzEuNTE3IDExMS42MDFjLS41OS4zNTMtLjk2Mi42ODktLjk2MiAxLjQ5djEyLjI0YzAgNS4zNjMtMy4wNzIgOC43MzUtNi45OTcgOC43MzVoLS4zNDJjLTIuODgzIDAtNi45OTgtMy4zNzItNi45OTgtOC43MzV2LTEyLjM0MWMwLTIuNTI1IDEuMjYyLTMuNjUyIDMuMzMyLTQuODczbDE5LjU1Mi0xMS4yMTZjMi4wNjktMS41NTIgMy4wMDItMi43MzIgMy4yNDgtMy41ODJ2LTE1LjUyYzAtNS40MTEgMi44MzEtOC44MzUgNi44MzYtOC44MzVoLjM0MmMzLjg5NSAwIDYuODM3IDMuNDI0IDYuODM3IDguMDM2djE1LjUyYzAgMS4yMTQgMS4wNCAyLjUxNyAzLjI0OSAzLjU4MmwxOS41NTEgMTEuMjE2YzIuMDY4IDEuMjIgMy4zMjkgMi4zNDYgMy4zMjkgNC44NzF2MTIuMzQxYzAgNS4zNjMtNC4xMTUgOC43MzUtNi45OTggOC43MzVoLS4zNDJjLTMuOTI2IDAtNi45OTctMy4zNzItNi45OTctOC43MzV2LTEyLjI0YzAtLjgtLjM3LTEuMTM2LS45NjItMS40ODlsLTE5LjI2My0xMS4xMzdjLS41ODgtLjU0Ni0xLjExOC0uODE2LTEuODIuODE2aC0uMDAyYy0uNzAzIDAtMS4yMzQuMjctMS44Mi44MTZsLTE5LjI2MyAxMS4xMzd6IiBmaWxsPSIjMjNhNmUwIi8+PHBhdGggZD0iTTIwOS4zMiA4MS4yOThsMTUuNjM4IDEzLjg1OGMyLjk2OCAyLjY0MSA0LjY4OCA0LjcyMSA0LjY4OCA4LjMyM3Y4LjMyM2MwIDQuMTEzLTMuMTYzIDguNDg1LTcuMjQ2IDguNDg1aC0uNDU0Yy00LjA4NCAwLTcuMjQ3LTQuMzcyLTcuMjQ3LTguNDg1di04LjMyM2MwLTMuNTg4LTEuNzItNS42ODItNC42ODgtOC4zMjNsLTE1LjYzOC0xMy44NThjLTIuOTY4LTIuNjQtNC42ODgtNC42ODgtNC42ODgtOC4zMjN2LS41NjdjMC0uODUzLjMtMS42NDQuODQyLTIuMjg1bDEwLjEwMS0xMS4zMjJjMS42OS0xLjk3NiA0LjM0Mi0zLjM5NSA3LjUzOC0zLjM5NWgyNi4zNjVjMi41NzggMCA0Ljk2MiAxLjA1MyA3LjAzMiAyLjgzNmw4LjU4NyA5LjYxMWMtMTYuMTM3IDEuMTg4LTMwLjQ0NSA3LjM3OS0zMy4yMDYgOS4zMjF6TTQ2LjY3OCA4MS4yOThsLTEwLjQxNSAxMS43MjFjLTE2LjEzNSAxLjE4OC0zMC40NDMgNy4zNzktMzMyLjA2IDkuMzIxbDguNTg3LTkuNjExYzIuMDctMS43ODMgNC40NTQtMi44MzYgNy4wMzItMi44MzZoMjYuMzY1YzMuMTk2IDAgNS44NDggMS40MTkgNy41MzggMy4zOTVsMTAuMSAxMS4zMjJjLjU0Mi42NDEuODQyIDEuNDMyLjg0MiAyLjI4NXYuNTY3YzAgMy42MzUtMS43MiA1LjY4My00LjY4OCA4LjMyM2wtMTUuNjM4IDEzLjg1OGMtMi45NjggMi42NDEtNC42ODggNC43MjEtNC42ODggOC4zMjN2OC4zMjNjMCA0LjExMy0zLjE2MyA4LjQ4NS03LjI0NiA4LjQ4NWgtLjQ1NDYyYy00LjA4MyAwLTcuMjQ2LTQuMzcyLTcuMjQ2LTguNDg1di04LjMyM2MwLTMuNTg4LTEuNzItNS42ODItNC42ODgtOC4zMjNsLTE1LjYzOC0xMy44NThjLTIuOTY4LTIuNjQtNC42ODctNC43MjEtNC42ODctOC4zMjN6IiBmaWxsPSIjYzk3MTM0Ii8+PHBhdGggZD0iTTE4MS42NTIgNDguMzcxYy0xLjI4OSAwLTIuMTM5LS43OC0yLjEzOS0yLjAzN3YtOS4xOGMwLTEuMjU4Ljg1LTEuNzQ3IDIuMTM5LTEuNzQ3aC4zNDJjMS4yODkgMCAyLjEzOS40ODkgMi4xMzkgMS43NDd2OS4xOGMwIDEuMjU4LS44NSAyLjAzNy0yLjEzOSAyLjAzN3ptLTIxLjQzOCAwYy0xLjI4OSAwLTIuMTM5LS43OC0yLjEzOS0yLjAzN3YtOS4xOGMwLTEuMjU4Ljg1LTEuNzQ3IDIuMTM5LTEuNzQ3aC4zNDJjMS4yODkgMCAyLjEzOS40ODkgMi4xMzkgMS43NDd2OS4xOGMwIDEuMjU4LS44NSAyLjAzNy0yLjEzOSAyLjAzN3ptLTE0My41ODUgMjQuMTM0bDE5LjI4NiA5LjA3NGMxLjI3OC42MDIgMi41ODguOTA2IDMuODk2LjkwNmgwYzEuMzA4IDAgMi42MTgtLjMwNCAzLjg5Ni0uOTA2bDE5LjI4Ni05LjA3NGMxLjE4NC0uNTk0IDIuNDY1LTEuMTkxIDMuNzA0LTEuODlsMTguNTUtMTAuNTEyYzQuNjEzLTIuMTk1IDUuNy02Ljk3MiA0LjA0My0xMi4xMjItMS44NDgtMy41MDMtNC45NzEtNi4wMzUtOC44MTMtNi44MzdsLTIwLjEzNC0yLjI5Yy0yLjAzNC0uMjMzLTMuOTMxLTEuMDgyLTUuMzU4LTIuNDE3bC0xNS45OTItMTQuMjRjLS4yLS4xNzctLjM5NS0uMzU4LS41ODctLjU0NmwtMi4wNzktMi4wMzNjLS41NzQtLjU2MS0xLjMyNS0uOTEtMS45NjQtMS4zMDRoLDBsLTIwLjI2My0xMi4yMDVjLTUuNjctMy4zOTYtMTIuNjQyLTMuMzk2LTE4LjMxNiAwbC0xOS4zNTggMTEuNjE2Yy0uNjM5LjM5My0xLjM5LjcyNC0xLjk2MyAxLjMwNWwtMi4wOCAyLjAzM2MtLjE5Mi4xODgtLjM4Ny4zNjktLjU4Ny41NDZsLTE1Ljk5MiAxNC4yNGMtMS40MjcgMS4zMzUtMy4zMjQgMi4xODQtNS4zNTggMi40MTdsLTIwLjEzNCAyLjI5Yy0zLjgzMi40MzctNi45NjYgMi45NzEtOC44MTMgNi44MzgtMi4xOSA0LjYxNC0uNTY5IDkuOTI3IDQuMDQzIDEyLjEyMmwzLjU3IDQuMDIyYy0xLjY5MS0xLjk3Ny00LjM0Mi0zLjM5Ni03LjUzOC0zLjM5NmgtMjYuMzY1Yy0yLjU3OCAwLTQuOTYzIDEuMDUzLTcuMDMyIDIuODM2bC04LjU4NyA5LjYxMWMxNi4xMzQtMS4xODcgMzAuNDQyLTcuMzc4IDMyLjA2LTkuMzIxbDEwLjQxNSA4LjY3MWMyLjk2OCAyLjY0IDQuNjg4IDQuNzM1IDQuNjg4IDguMzIydi41NjdjMCAuODUzLS4zIDEuNjQ0LS44NDIgMi4yODVsLTEwLjEgMTEuMzIyYy0xLjY5IDEuOTc2LTQuMzQyIDMuMzk1LTcuNTM4IDMuMzk1aDI4Ljc5YzIuNTc4IDAgNC45NjMtMS4wNTMgNy4wMzItMi44MzZsOC4xNjItOS4xMzctNy4wMzIgOC4yNDRjLTIuMDcgMS43ODMtNC40NTQgMi44MzYtNy4wMzIgMi44MzZoLTI2LjM2NWMtMy4xOTYgMC01Ljg0OC0xLjQxOS03LjUzOC0zLjM5NWwtMTAuMDktMTEuMzIyYy0uNTQxLS42NDEtLjg0MS0xLjQzMi0uODQxLTIuMjg1di0uNTY3YzAtMy41ODggMS43MTktNS42ODIgNC42ODctOC4zMjNsMTUuNjM4LTEzLjg1OGMyLjk2OC0yLjY0IDQuNjg4LTQuNjg4IDQuNjg4LTguMzIzdi04LjMyM2MwLTQuMTEzIDMuMTYzLTguNDg1IDcuMjQ3LTguNDg1aC40NTRjNC4wODQgMCA3LjI0NyA0LjM3MiA3LjI0NyA4LjQ4NXY4LjMyM2MwIDMuNTg4IDEuNzIgNS42ODIgNC42ODggOC4zMjNsLjM4OS4zNDZjMS44NjYgMS40NzMgMi44ODYgMy42NDQgMi44ODYgNS44ODggMCAuNTM0LS4xMDggMS4wNjgtLjMyMSAxLjU2MmwtOS40MDcgMTAuMTY3Yy0uODQzIDEuMDc3LTEuMzMxIDIuMzc5LTEuNDY4IDMuNjc0bC0xLjc3OSA5LjkyOWMtLjI5NSAxLjY0Mi4zNzUgMy4zMjkgMS42MDcgNC4zNTFsMTUuODMxIDEzLjIyOWMyLjEyMiAxLjc2NSS0LjczOCA4LjY3MSA0LjczOCAyLjgzNiA3LjA2OCAxLjc4MiA5LjQ5MyAyLjg1MyAxMS45OSA5LjYyNWMxLjY3Ni44MzcgMy41NjkgMS4zMDMgNS4yMDkgMS4zMDNoLjAwNGM0LjM0MSAwIDguMzU1LTIuNDIgMTAuNDUyLTYuMzU0bDYuNTM1LTEyLjM5NGMuMjc1LS41MTQuNDIzLTEuMDYzLjQyMy0xLjYxOSAwLTEuNzgtLjc5NS0zLjQ2LTEuNzgtNC40ODdsLTkuNTY4LTkuMjQyIDEwLjEyMyAxMS40MjNjMS40NjggMS42NiAzLjQ4OCAyLjYxNyA1LjYzMyAyLjYxN2gyOC4xOThjMi4xNDQgMCA0LjE2NS0uOTU3IDUuNjM0LTIuNjE3bDkuNTY5LTEwLjg2N2MxLjQ2OS0xLjY2IDIuMjc5LTMuNzIxIDIuMjc5LTUuODQ3di0yMS45ODZjMC00LjUzLTMuNDEzLTguMTg2LTcuNjI3LTguMTg2aC0yOC43NDNjLTQuMjE0IDAtNy42MjcgMy42NTYtNy42MjcgOC4xODZ2MjEuOTg2YzAgMi4xMjYtLjgxIDQuMTg2LTIuMjc1IDEuODQ3bC0uMjMuMjYxIDguNTg4IDkuNzQyYzEuNDY4IDEuNjYgMy40ODggMi42MTcgNS42MzMgMi42MTdoMjguMTk4YzIuMTQ1IDAgNC4xNjYtLjk1NyA1LjYzNC0yLj۶E3bDkuNTY5LTEwLjg2N2MxLjQ2OS0xLjY2IDIuMjc5LTMuNzIxIDIuMjc5LTUuODQ3di0yMS45ODZjMC00LjUzLTMuNDEzLTguMTg2LTcuNjI3LTguMTg2aC0yOC43NDNjLTQuMjE0IDAtNy42MjcgMy42NTYtNy42MjcgOC4xODZ2MjEuOTg2YzAgMi4xMjYtLjgxIDQuMTg2LTIuMjc1IDEuODQ3bC00LjU0OCA1LjE2MiAyLjM3NS0yLjY5NGMxLjQ2OS0xLjY2IDIuMjc5LTMuNzIxIDIuMjc5LTUuODQ3di0yMS45ODZjMC00LjUzLTMuNDEzLTguMTg2LTcuNjI3LTguMTg2aC0yOC43NDNjLTQuMjE0IDAtNy42MjcgMy42NTYtNy42MjcgOC4xODZ2MjEuOTg2YzAgMi4xMjctLjgwOSA0LjE4Ny0yLjI3NSA1Ljg0N2wtOS41NyAxMC44NjctNC4zNDYgNC45MzVjLTEuNDY4IDEuNjYtMy40ODggMi42MTctNS42MzMgMi42MTdoLTI4LjE5OGMtMi4xNDUgMC00LjE2Ni0uOTU3LTUuNjM0LTIuNjE3bC05LjU2OS0xMC44NjdjLTEuNDY5LTEuNjYtMi4yNzktMy43MjEtMi4yNzktNS44NDd2LTIxLjk4NmMwLTQuNTMgMy40MTMtOC4xODYgNy42MjctOC4xODZoMjguNzQzYzQuMjE0IDAgNy42MjcgMy42NTYgNy42MjcgOC4xODZ2MjEuOTg2YzAgMi4xMjYtLjgxIDQuMTg2LTIuMjc1IDUuODQ3bC0xLjY4NyAxLjkyMXptMzEuNDgzLTEwNS40NTNjMC00LjExMiAzLjE2My04LjQ4NSA3LjI0Ni04LjQ4NWguNDU1YzQuMDgzIDAgNy4yNDYgNC4zNzIgNy4yNDYgOC40ODV2OC4zMjNjMCAzLjU4OC0xLjcxOSA1LjY4Mi00LjY4NyA4LjMyM2wtMTUuNjM4IDEzLjg1OGMtMi45NjggMi42NC00LjY4OCA0LjY4OC00LjY4OCA4LjMyM3YuNTY3YzAgLjg1My4zIDEuNjQ0Ljg0MiAyLjI4NWwxMC4xMDEgMTEuMzIyYzEuNjkgMS45NzYgNC4zNDIgMy4zOTUgNy41MzggMy4zOTVoMjYuMzY1YzIuNTc4IDAgNC45NjMtMS4wNTMgNy4wMzItMi44MzZsMTAuNjQ0LTExLjkwOGMuNjg2LS45NDEgMS4wMjgtMi4wNjcgMS4wMjgtMy4yNDV2LS41NjdjMC0zLjYzNS0xLjcyLTUuNjgzLTQuNjg4LTguMzIzbC0xNS42MzgtMTMuODU4Yy0yLjk2OC0yLjY0MS00LjY4OC00LjcyMS00LjY4OC04LjMyM3YtOC4zMjNjMC00LjExMy0zLjE2My04LjQ4NS03LjI0Ni04LjQ4NWgtLjQ1NDYyYy00LjA4MyAwLTcuMjQ2IDQuMzcyLTcuMjQ2IDguNDg1eiIgZmlsbD0iI2YyNzIyMyIvPjwvc3ZnPg==', // Default icon
            rdns: 'io.metamask'
        };
        const provider = window.ethereum;
        providers.set(info.uuid, { info, provider });

        // Re-render if needed
        const btn = document.getElementById("wallet-btn-inner");
        if (btn && !getState()) {
            renderLoggedOut(btn);
        }
    }
}, 500);

function getAvailableProviders() {
    return Array.from(providers.values());
}

function selectProvider(uuid) {
    if (providers.has(uuid)) {
        selectedProvider = providers.get(uuid).provider;
    } else if (uuid === 'io.metamask' && window.ethereum) {
        selectedProvider = window.ethereum;
    } else {
        console.error(`Provider with UUID ${uuid} not found.`);
        selectedProvider = null;
    }
}

function clearState() {
  sessionStorage.removeItem(SIWE_STATE_KEY)
}

function setState(data) {
  sessionStorage.setItem(SIWE_STATE_KEY, JSON.stringify(data))
}

function getState() {
  try {
    return JSON.parse(sessionStorage.getItem(SIWE_STATE_KEY))
  } catch {
    return null
  }
}

// Build a EIP-4361 SIWE message
function buildSiweMessage(address, nonce) {
  const now = new Date()
  const issued = now.toISOString()
  const expiration = new Date(now.getTime() + 24 * 60 * 60 * 1000).toISOString()

  const lines = [
    `${SIWE_DOMAIN} wants you to sign in with your Ethereum account:`,
    address,
    ``,
    `Sign in to such.gallery`,
    ``,
    `URI: ${SIWE_ORIGIN}`,
    `Version: 1`,
    `Chain ID: 1`,
    `Nonce: ${nonce}`,
    `Issued At: ${issued}`,
    `Expiration Time: ${expiration}`,
  ]

  return lines.join("\n")
}

// Request a nonce from the server
async function fetchNonce() {
  const res = await fetch("/api/siwe/nonce", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    credentials: "same-origin",
  })

  if (!res.ok) throw new Error("Failed to fetch nonce")

  const data = await res.json()
  return data.nonce
}

// Checksum an address via server (EIP-55)
// Some wallet extensions (zilPay etc.) return non-checksummed addresses
// which breaks the siwe parser. We let the server (keccak256 via NIF) do it.
async function checksumAddress(address) {
  const res = await fetch("/api/siwe/checksum", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ address }),
  })
  if (!res.ok) return address
  const data = await res.json()
  return data.address
}

// Get connected accounts from wallet
async function getAccounts() {
  if (!selectedProvider) throw new Error("No wallet provider selected");
  const accounts = await selectedProvider.request({ method: "eth_requestAccounts" });
  return accounts;
}

// Personal sign a message
async function signMessage(address, message) {
  if (!selectedProvider) throw new Error("No wallet provider selected");
  return selectedProvider.request({
    method: "personal_sign",
    params: [message, address],
  });
}

// Verify with server
async function verifyWithServer(message, signature) {
  const res = await fetch("/api/siwe/verify", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    credentials: "same-origin",
    body: JSON.stringify({ message, signature }),
  })

  if (!res.ok) {
    const err = await res.json()
    throw new Error(err.error || "Verification failed")
  }

  return await res.json()
}

// Full sign-in flow
async function signIn() {
  if (!walletAvailable()) {
    window.open("https://metamask.io/download/", "_blank")
    return null
  }

  try {
    const accounts = await getAccounts()
    let address = accounts[0]

    // Ensure EIP-55 checksum before building SIWE message
    // (some extensions like zilPay return non-checksummed addresses)
    address = await checksumAddress(address)

    const nonce = await fetchNonce()
    const message = buildSiweMessage(address, nonce)
    const signature = await signMessage(address, message)
    const user = await verifyWithServer(message, signature)

    setState(user)
    return user
  } catch (err) {
    console.error("SIWE sign-in failed:", err)
    throw err
  }
}

// Check session with server
async function checkSession() {
  try {
    const res = await fetch("/api/siwe/me", { credentials: "same-origin" })

    if (res.ok) {
      const user = await res.json()
      setState(user)
      return user
    } else {
      clearState()
      return null
    }
  } catch {
    return null
  }
}

// Logout
async function logout() {
  try {
    await fetch("/api/siwe/session", {
      method: "DELETE",
      credentials: "same-origin",
    })
  } catch {
    // ignore
  }
  clearState()
}

// --- Wallet button UI (self-initializing) ---

function renderLoggedIn(btn, user) {
  const addr = user.address || user.wallet_address || ""
  const short = addr.slice(0, 6) + "\u2026" + addr.slice(-4)
  btn.innerHTML =
    '<div class="flex items-center gap-2">' +
    '<span class="w-2 h-2 rounded-full bg-green-500"></span>' +
    '<span class="text-sm text-gray-700">' + short + "</span>" +
    '<button id="wallet-logout-btn" class="text-xs text-gray-400 hover:text-red-500 transition-colors">\u2715</button>' +
    "</div>"
  document.getElementById("wallet-logout-btn").addEventListener("click", handleLogout)
}

function renderLoggedOut(btn) {
  const availableProviders = getAvailableProviders();

  if (availableProviders.length > 1) {
    let options = availableProviders.map(p => 
      `<li class="flex items-center gap-2 px-3 py-2 text-sm text-gray-800 hover:bg-gray-100 cursor-pointer" data-uuid="${p.info.uuid}">
         <img src="${p.info.icon}" alt="${p.info.name}" class="w-5 h-5 rounded-md" />
         <span>${p.info.name}</span>
       </li>`
    ).join('');

    btn.innerHTML = `
      <div id="wallet-connect-dropdown" class="relative">
        <button id="wallet-connect-btn" class="px-3 py-1.5 text-sm font-medium text-white bg-gray-900 rounded-lg hover:bg-gray-700 transition-colors cursor-pointer">Connect Wallet</button>
        <ul id="wallet-provider-list" class="absolute z-10 mt-2 w-56 bg-white border border-gray-200 rounded-lg shadow-lg hidden">
          ${options}
        </ul>
      </div>
    `;

    const connectBtn = document.getElementById("wallet-connect-btn");
    const providerList = document.getElementById("wallet-provider-list");

    connectBtn.addEventListener("click", () => {
      providerList.classList.toggle("hidden");
    });

    providerList.addEventListener("click", handleProviderSelect);

    // Close dropdown if clicking outside
    document.addEventListener("click", (event) => {
        if (!document.getElementById("wallet-connect-dropdown")?.contains(event.target)) {
            providerList.classList.add("hidden");
        }
    });

  } else if (availableProviders.length === 1) {
    const provider = availableProviders[0];
    btn.innerHTML =
      `<button id="wallet-connect-btn" data-uuid="${provider.info.uuid}" class="px-3 py-1.5 text-sm font-medium text-white bg-gray-900 rounded-lg hover:bg-gray-700 transition-colors cursor-pointer flex items-center gap-2">
         <img src="${provider.info.icon}" alt="${provider.info.name}" class="w-5 h-5 rounded-md" />
         Connect ${provider.info.name}
       </button>`;
    document.getElementById("wallet-connect-btn").addEventListener("click", handleProviderSelect);
  } else {
    btn.innerHTML =
      '<a href="https://metamask.io/download/" target="_blank" class="px-3 py-1.5 text-sm font-medium text-gray-600 border border-gray-300 rounded-lg hover:border-gray-500 transition-colors">Install Wallet</a>';
  }
}

async function handleProviderSelect(event) {
    const target = event.target.closest('[data-uuid]');
    if (!target) return;

    const uuid = target.dataset.uuid;
    selectProvider(uuid);
    
    const providerList = document.getElementById("wallet-provider-list");
    if (providerList) providerList.classList.add("hidden");

    await handleSignIn();
}

async function handleSignIn() {
  const btn = document.getElementById("wallet-btn-inner")
  if (!btn) return
  btn.innerHTML = '<span class="text-sm text-gray-400">Connecting\u2026</span>'
  try {
    const user = await signIn()
    renderLoggedIn(btn, user)
  } catch (err) {
    console.error("SuchGallery: sign-in failed", err)
    renderLoggedOut(btn)
  }
}

async function handleLogout() {
  await logout()
  const btn = document.getElementById("wallet-btn-inner")
  if (btn) renderLoggedOut(btn)
}

// Auto-init on DOM ready
function initWalletButton() {
  const btn = document.getElementById("wallet-btn-inner")
  if (!btn) return

  const existing = getState()
  if (existing) {
    renderLoggedIn(btn, existing)
    return
  }

  checkSession().then((user) => {
    if (user) {
      renderLoggedIn(btn, user)
    } else {
      renderLoggedOut(btn)
    }
  }).catch(() => {
    renderLoggedOut(btn)
  })
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initWalletButton)
} else {
  initWalletButton()
}

// Export as global
window.SuchGallery = {
  signIn,
  logout,
  checkSession,
  getState,
  walletAvailable,
}
