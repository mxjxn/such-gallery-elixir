defmodule SuchGalleryElixirWeb.UserSocket do
  @moduledoc """
  WebSocket entry for gallery channel clients (magazine hook and Three.js walk).

  Resolves the authenticated user from the HTTP session (set by SIWE login) and
  assigns their identity to the socket so channels can use it for presence and chat.
  Unauthenticated visitors get nil — channels fall back to guest params.
  """

  use Phoenix.Socket

  channel "room:*", SuchGalleryElixirWeb.RoomChannel

  alias SuchGalleryElixir.Accounts

  @impl true
  def connect(_params, socket, connect_info) do
    user =
      case get_in(connect_info, [:session, "user_id"]) do
        nil -> nil
        user_id -> Accounts.get_user(user_id)
      end

    {:ok, assign(socket, :current_user, user)}
  end

  @impl true
  def id(socket), do: socket.id
end
