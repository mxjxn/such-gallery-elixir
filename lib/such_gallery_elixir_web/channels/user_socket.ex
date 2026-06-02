defmodule SuchGalleryElixirWeb.UserSocket do
  @moduledoc """
  WebSocket entry for gallery channel clients (magazine hook and future Three.js).
  """

  use Phoenix.Socket

  channel "room:*", SuchGalleryElixirWeb.RoomChannel

  @impl true
  def connect(_params, socket, _connect_info), do: {:ok, socket}

  @impl true
  def id(socket), do: socket.id
end
