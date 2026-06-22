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
  // Session valid for 24 hours
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
    const address = accounts[0]
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

// Export as global for easy use in templates
window.SuchGallery = {
  signIn,
  logout,
  checkSession,
  getState,
  walletAvailable,
}
