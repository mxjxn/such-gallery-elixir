defmodule SuchGalleryElixirWeb.Components.WalletButton do
  @moduledoc """
  Wallet connect/disconnect button container.

  The actual UI logic lives in `assets/js/wallet_connect.js` which
  self-initializes and wires up the button on DOM ready. This component
  only renders the empty container div.
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
    """
  end
end
