defmodule SuchGalleryElixirWeb.PageController do
  use SuchGalleryElixirWeb, :controller

  alias SuchGalleryElixir.Galleries

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  @doc "First-person Three.js walkthrough for a gallery room."
  def walk(conn, %{"slug" => slug}) do
    case Galleries.get_gallery_by_slug(slug) do
      nil ->
        conn
        |> put_flash(:error, "Gallery not found")
        |> redirect(to: ~p"/")

      gallery ->
        render(conn, :walk,
          layout: false,
          page_title: gallery.name,
          gallery: gallery,
          guest_name: "Guest-#{:rand.uniform(9999)}",
          guest_color: random_color()
        )
    end
  end

  defp random_color do
    "hsl(#{:rand.uniform(360)}, 70%, 55%)"
  end
end
