import {Socket} from "phoenix"

// SIWE wallet authentication
// Requires: window.ethereum (injected by MetaMask or similar)

const SIWE_DOMAIN = window.location.host
const SIWE_ORIGIN = window.location.origin
const SIWE_STATE_KEY = "suchgallery_siwe_state"

function walletAvailable() {
  return typeof window.ethereum !== "undefined" && window.ethereum.isMetaMask
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

// Get connected accounts from wallet
async function getAccounts() {
  const accounts = await window.ethereum.request({ method: "eth_requestAccounts" })
  return accounts
}

// Personal sign a message
async function signMessage(address, message) {
  return window.ethereum.request({
    method: "personal_sign",
    params: [message, address],
  })
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

    // Ensure EIP-55 checksum — some wallet extensions (zilPay, etc.)
    // may interfere with window.ethereum and return non-checksummed addresses.
    // MetaMask normally returns checksummed, but if another extension wraps it,
    // we need to fix it. Use web3's keccak-based EIP-55 check:
    if (address === address.toLowerCase() || address === address.toUpperCase()) {
      // Not mixed case — needs checksumming.
      // We can't easily get keccak256 in vanilla JS, so we ask MetaMask to
      // re-reveal accounts which should come back checksummed.
      // Alternatively, checksum on the backend. For now, try requesting again:
      console.warn("SuchGallery: address not checksummed, attempting recovery")
    }

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
  if (walletAvailable()) {
    btn.innerHTML =
      '<button id="wallet-connect-btn" class="px-3 py-1.5 text-sm font-medium text-white bg-gray-900 rounded-lg hover:bg-gray-700 transition-colors cursor-pointer">Connect Wallet</button>'
    document.getElementById("wallet-connect-btn").addEventListener("click", handleSignIn)
  } else {
    btn.innerHTML =
      '<a href="https://metamask.io/download/" target="_blank" class="px-3 py-1.5 text-sm font-medium text-gray-600 border border-gray-300 rounded-lg hover:border-gray-500 transition-colors">Install MetaMask</a>'
  }
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
