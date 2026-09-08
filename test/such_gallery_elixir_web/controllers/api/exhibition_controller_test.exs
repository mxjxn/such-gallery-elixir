defmodule SuchGalleryElixirWeb.Controllers.API.ExhibitionControllerTest do
  use SuchGalleryElixirWeb.ConnCase, async: true

  alias SuchGalleryElixir.AccountsFixtures
  alias SuchGalleryElixir.Galleries

  import SuchGalleryElixir.GalleriesFixtures

  test "serves current and immutable exhibition manifests with distinct cache policies", %{
    conn: conn
  } do
    owner = AccountsFixtures.user_fixture()
    gallery = gallery_fixture(%{owner_id: owner.id})
    assert {:ok, publication} = Galleries.publish_gallery(gallery)

    current_conn = get(conn, "/api/v1/exhibitions/#{gallery.slug}")
    assert json_response(current_conn, 200)["revision"] == publication.revision

    assert get_resp_header(current_conn, "cache-control") == [
             "public, max-age=60, stale-if-error=86400"
           ]

    assert [_etag] = get_resp_header(current_conn, "etag")

    revision_conn = get(conn, "/api/v1/exhibitions/#{gallery.slug}/manifest/1")
    assert json_response(revision_conn, 200)["revision"] == 1

    assert get_resp_header(revision_conn, "cache-control") == [
             "public, max-age=31536000, immutable"
           ]
  end

  test "only the gallery owner can publish", %{conn: conn} do
    owner = AccountsFixtures.user_fixture()
    stranger = AccountsFixtures.user_fixture()
    gallery = gallery_fixture(%{owner_id: owner.id})

    forbidden_conn =
      conn
      |> AccountsFixtures.authed_conn(stranger)
      |> post("/api/v1/exhibitions/#{gallery.slug}/publish")

    assert json_response(forbidden_conn, 403)["error"] == "Not gallery owner"

    published_conn =
      build_conn()
      |> AccountsFixtures.authed_conn(owner)
      |> post("/api/v1/exhibitions/#{gallery.slug}/publish")

    assert json_response(published_conn, 201)["revision"] == 1
  end

  test "an unpublished gallery is absent from the current endpoint", %{conn: conn} do
    gallery = gallery_fixture()
    conn = get(conn, "/api/v1/exhibitions/#{gallery.slug}")
    assert json_response(conn, 404)["error"] == "Exhibition not found"
  end
end
