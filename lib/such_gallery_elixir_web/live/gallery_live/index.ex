defmodule SuchGalleryElixirWeb.GalleryLive.Index do
  @moduledoc """
  Home page: lists all galleries with a card grid and a create button.
  """

  use SuchGalleryElixirWeb, :live_view

  alias SuchGalleryElixir.Galleries

  @impl true
  def mount(_params, _session, socket) do
    galleries = Galleries.list_galleries()

    {:ok,
     socket
     |> assign(:page_title, "wow such gallery")
     |> assign(:galleries, galleries)}
  end
end
