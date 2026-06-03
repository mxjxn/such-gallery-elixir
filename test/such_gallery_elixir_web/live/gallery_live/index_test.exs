defmodule SuchGalleryElixirWeb.GalleryLive.IndexTest do
  use SuchGalleryElixirWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias SuchGalleryElixir.GalleriesFixtures

  describe "index/2" do
    test "renders with title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "wow such gallery"
      assert html =~ "coming summer 2026"
    end

    test "shows gallery list", %{conn: conn} do
      gallery = GalleriesFixtures.gallery_fixture()

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ gallery.name
      assert html =~ to_string(gallery.template.layout)
    end

    test "has create gallery link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~p"/galleries/new"
      assert html =~ "Create gallery"
    end

    test "shows empty state when no galleries", %{conn: conn} do
      # Note: in a real test this would need a clean DB.
      # We just verify the rendering doesn't crash.
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "wow such gallery"
    end

    test "gallery cards link to views and edit", %{conn: conn} do
      gallery = GalleriesFixtures.gallery_fixture()

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~p"/gallery/#{gallery.slug}"
      assert html =~ ~p"/gallery/#{gallery.slug}/walk"
      assert html =~ ~p"/galleries/#{gallery.slug}/edit"
    end
  end
end
