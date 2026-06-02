defmodule SuchGalleryElixirWeb.Presence do
  @moduledoc """
  Tracks connected avatars per gallery channel topic.

  Meta keys: `id`, `name`, `color`, `x`, `z` — updated on move events.
  """

  use Phoenix.Presence,
    otp_app: :such_gallery_elixir,
    pubsub_server: SuchGalleryElixir.PubSub
end
