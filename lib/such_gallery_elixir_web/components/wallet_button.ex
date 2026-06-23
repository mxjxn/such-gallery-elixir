defmodule SuchGalleryElixirWeb.Components.WalletButton do
  @moduledoc """
  A wallet connect/disconnect button that integrates with the SIWE flow.

  Renders a minimal button in the top-right corner. Uses the global
  `window.SuchGallery` JS API from `wallet_connect.js` for the actual
  sign-in flow. Automatically checks session state on page load.
  """
  use Phoenix.Component

  attr :current_user, :map, default: nil

  def wallet_button(assigns) do
    ~H"""
    <div id="wallet-btn" class="fixed top-4 right-4 z-50">
      <div id="wallet-btn-inner">
        <span class="text-sm text-gray-400">…</span>
      </div>
    </div>
    <script>
      document.addEventListener("DOMContentLoaded", async function() {
        const btn = document.getElementById("wallet-btn-inner");
        if (!btn) return;
        const SG = window.SuchGallery;
        if (!SG) { btn.textContent = "Wallet N/A"; return; }

        // Check existing session
        const existing = SG.getState();
        if (existing) {
          renderLoggedIn(btn, existing);
          return;
        }

        // Check server session
        try {
          const user = await SG.checkSession();
          if (user) {
            renderLoggedIn(btn, user);
          } else {
            renderLoggedOut(btn);
          }
        } catch (e) {
          renderLoggedOut(btn);
        }
      });

      function renderLoggedIn(btn, user) {
        const addr = user.address || user.wallet_address || "";
        const short = addr.slice(0,6) + "\u2026" + addr.slice(-4);
        btn.innerHTML = '<div class="flex items-center gap-2">' +
          '<span class="w-2 h-2 rounded-full bg-green-500"></span>' +
          '<span class="text-sm text-gray-700">' + short + '</span>' +
          '<button id="wallet-logout-btn" class="text-xs text-gray-400 hover:text-red-500 transition-colors">\u2715</button>' +
          '</div>';
        document.getElementById("wallet-logout-btn").addEventListener("click", handleLogout);
      }

      function renderLoggedOut(btn) {
        if (window.SuchGallery && SuchGallery.walletAvailable()) {
          btn.innerHTML = '<button id="wallet-connect-btn" class="px-3 py-1.5 text-sm font-medium text-white bg-gray-900 rounded-lg hover:bg-gray-700 transition-colors cursor-pointer">Connect Wallet</button>';
          document.getElementById("wallet-connect-btn").addEventListener("click", handleSignIn);
        } else {
          btn.innerHTML = '<a href="https://metamask.io/download/" target="_blank" class="px-3 py-1.5 text-sm font-medium text-gray-600 border border-gray-300 rounded-lg hover:border-gray-500 transition-colors">Install MetaMask</a>';
        }
      }

      async function handleSignIn() {
        const btn = document.getElementById("wallet-btn-inner");
        btn.innerHTML = '<span class="text-sm text-gray-400">Connecting\u2026</span>';
        try {
          const user = await SuchGallery.signIn();
          renderLoggedIn(btn, user);
        } catch (err) {
          console.error("Sign-in failed:", err);
          renderLoggedOut(btn);
        }
      }

      async function handleLogout() {
        await SuchGallery.logout();
        const btn = document.getElementById("wallet-btn-inner");
        renderLoggedOut(btn);
      }
    </script>
    """
  end
end
