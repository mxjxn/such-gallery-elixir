defmodule SuchGalleryElixirWeb.GalleryLiveTest do
  use SuchGalleryElixirWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias SuchGalleryElixir.Galleries
  alias SuchGalleryElixir.GalleriesFixtures

  describe "show/2" do
    test "renders gallery and placements", %{conn: conn} do
      gallery = GalleriesFixtures.gallery_fixture()
      artwork = GalleriesFixtures.artwork_fixture()
      slot = GalleriesFixtures.slot_fixture(gallery)
      {:ok, _} = Galleries.assign_artwork_to_slot(gallery, artwork, slot, 0)

      {:ok, _view, html} = live(conn, ~p"/gallery/#{gallery.slug}")

      assert html =~ gallery.name
      assert html =~ artwork.artwork_url
    end

    test "redirects when gallery missing", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/gallery/no-such-gallery")
    end
  end
end
