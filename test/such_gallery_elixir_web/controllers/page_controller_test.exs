defmodule SuchGalleryElixirWeb.PageControllerTest do
  use SuchGalleryElixirWeb.ConnCase

  alias SuchGalleryElixir.GalleriesFixtures

  test "GET /gallery/:slug/walk", %{conn: conn} do
    gallery = GalleriesFixtures.gallery_fixture()

    conn = get(conn, ~p"/gallery/#{gallery.slug}/walk")
    html = html_response(conn, 200)

    assert html =~ gallery.name
    assert html =~ "gallery-walk-root"
    assert html =~ "gallery_walk.js"
  end
end
