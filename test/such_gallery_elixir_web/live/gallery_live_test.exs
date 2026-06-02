defmodule SuchGalleryElixirWeb.GalleryLiveTest do
  use SuchGalleryElixirWeb.ConnCase, async: false

  import Ecto.Query
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

    test "loads recent chat history on mount", %{conn: conn} do
      gallery = GalleriesFixtures.gallery_fixture()
      {:ok, _} = Galleries.create_chat_message(gallery.id, "Ada", "earlier hello")

      {:ok, _view, html} = live(conn, ~p"/gallery/#{gallery.slug}")

      assert html =~ "earlier hello"
      assert html =~ "Ada"
    end

    test "send_chat appends message to the feed", %{conn: conn} do
      gallery = GalleriesFixtures.gallery_fixture()

      {:ok, view, _html} = live(conn, ~p"/gallery/#{gallery.slug}")

      view
      |> form("#chat-form", %{text: "hello room"})
      |> render_submit()

      assert render(view) =~ "hello room"

      assert [_] =
               SuchGalleryElixir.Repo.all(
                 from(m in SuchGalleryElixir.Galleries.ChatMessage,
                   where: m.gallery_id == ^gallery.id and m.body == "hello room"
                 )
               )
    end

    test "send_chat does not duplicate on a single submit", %{conn: conn} do
      gallery = GalleriesFixtures.gallery_fixture()

      {:ok, view, _html} = live(conn, ~p"/gallery/#{gallery.slug}")

      view
      |> form("#chat-form", %{text: "once only"})
      |> render_submit()

      html = render(view)
      assert html =~ "once only"
      assert count_occurrences(html, "once only") == 1
    end

    test "presence_update with nested list does not crash", %{conn: conn} do
      gallery = GalleriesFixtures.gallery_fixture()

      {:ok, view, _html} = live(conn, ~p"/gallery/#{gallery.slug}")

      nested = [
        [
          %{"id" => "abc", "name" => "Ada", "color" => "#3366cc", "x" => 0, "z" => 0}
        ]
      ]

      view
      |> element("#gallery-presence-bridge")
      |> render_hook("presence_update", %{presences: nested})

      assert render(view) =~ "Ada"
    end
  end

  defp count_occurrences(haystack, needle) do
    haystack
    |> String.split(needle)
    |> length()
    |> Kernel.-(1)
  end
end
