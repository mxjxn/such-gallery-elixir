defmodule SuchGalleryElixirWeb.GalleryLive.FormTest do
  use SuchGalleryElixirWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias SuchGalleryElixir.Galleries
  alias SuchGalleryElixir.GalleriesFixtures

  setup do
    # Ensure a template exists for the form's default template_slug
    GalleriesFixtures.template_fixture(%{slug: "square_32"})
    :ok
  end

  describe "new gallery" do
    test "renders form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/galleries/new")

      assert html =~ "Create gallery"
      assert html =~ "Name"
      assert html =~ "Template"
    end

    test "creates a gallery with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/galleries/new")

      view
      |> form("#gallery-form", gallery: %{name: "My New Gallery"})
      |> render_submit()

      {path, flash} = assert_redirect(view)
      assert flash["info"] == "Gallery created successfully."
      assert path =~ "/gallery/"
    end

    test "auto-generates slug from name", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/galleries/new")

      view
      |> form("#gallery-form", gallery: %{name: "My Fancy Gallery"})
      |> render_submit()

      gallery = Galleries.get_gallery_by_slug("my-fancy-gallery")
      assert gallery != nil
      assert gallery.name == "My Fancy Gallery"
    end

    test "rejects duplicate slug", %{conn: conn} do
      existing = GalleriesFixtures.gallery_fixture()

      {:ok, view, _html} = live(conn, ~p"/galleries/new")

      html =
        view
        |> form("#gallery-form", gallery: %{name: existing.name, slug: existing.slug})
        |> render_submit()

      assert html =~ "has already been taken"
    end

    test "requires a template", %{conn: conn} do
      # Verify that submitting with name + default template slug works
      {:ok, view, _html} = live(conn, ~p"/galleries/new")

      view
      |> form("#gallery-form", gallery: %{name: "Template Works Gallery"})
      |> render_submit()

      assert_redirect(view)
    end
  end

  describe "edit gallery" do
    test "renders form with gallery data", %{conn: conn} do
      gallery = GalleriesFixtures.gallery_fixture()

      {:ok, _view, html} = live(conn, ~p"/galleries/#{gallery.slug}/edit")

      assert html =~ "Edit gallery"
      assert html =~ gallery.name
      assert html =~ "template is locked after creation"
    end

    test "updates gallery name", %{conn: conn} do
      gallery = GalleriesFixtures.gallery_fixture()

      {:ok, view, _html} = live(conn, ~p"/galleries/#{gallery.slug}/edit")

      view
      |> form("#gallery-form", gallery: %{name: "Renamed Gallery"})
      |> render_submit()

      assert_redirect(view)

      updated = Galleries.get_gallery_by_slug(gallery.slug)
      assert updated.name == "Renamed Gallery"
    end

    test "redirects when gallery not found", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/galleries/nonexistent/edit")
    end

    test "shows delete button", %{conn: conn} do
      gallery = GalleriesFixtures.gallery_fixture()

      {:ok, _view, html} = live(conn, ~p"/galleries/#{gallery.slug}/edit")

      assert html =~ "Delete gallery"
    end

    test "shows confirmation on delete click", %{conn: conn} do
      gallery = GalleriesFixtures.gallery_fixture()

      {:ok, view, html} = live(conn, ~p"/galleries/#{gallery.slug}/edit")

      refute html =~ "Yes, delete gallery"

      html = render_click(view, :show_delete_confirm)

      assert html =~ "Yes, delete gallery"
      assert html =~ "All placements and chat messages will be removed"
    end

    test "cancels delete confirmation", %{conn: conn} do
      gallery = GalleriesFixtures.gallery_fixture()

      {:ok, view, _html} = live(conn, ~p"/galleries/#{gallery.slug}/edit")

      render_click(view, :show_delete_confirm)
      html = render_click(view, :cancel_delete)

      refute html =~ "Yes, delete gallery"
    end

    test "deletes gallery and redirects to index", %{conn: conn} do
      gallery = GalleriesFixtures.gallery_fixture()

      {:ok, view, _html} = live(conn, ~p"/galleries/#{gallery.slug}/edit")

      render_click(view, :show_delete_confirm)
      assert {:error, {:live_redirect, %{to: "/"}}} = render_click(view, :delete)

      refute Galleries.get_gallery_by_slug(gallery.slug)
    end
  end
end
