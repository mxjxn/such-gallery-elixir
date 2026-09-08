defmodule SuchGalleryElixirWeb.Controllers.API.ExhibitionController do
  @moduledoc "Public reads and owner-controlled publication for exhibition manifests."

  use SuchGalleryElixirWeb, :controller

  alias SuchGalleryElixir.Galleries

  def show(conn, %{"slug" => slug}) do
    case Galleries.get_published_exhibition_by_slug(slug) do
      nil ->
        not_found(conn)

      publication ->
        send_manifest(conn, publication.manifest, "public, max-age=60, stale-if-error=86400")
    end
  end

  def revision(conn, %{"slug" => slug, "revision" => revision_string}) do
    with {revision, ""} <- Integer.parse(revision_string),
         publication when not is_nil(publication) <-
           Galleries.get_publication_by_slug_and_revision(slug, revision) do
      send_manifest(conn, publication.manifest, "public, max-age=31536000, immutable")
    else
      _ -> not_found(conn)
    end
  end

  def publish(conn, %{"slug" => slug}) do
    with gallery when not is_nil(gallery) <- Galleries.get_gallery_by_slug(slug),
         true <- owns_gallery?(conn.assigns.current_user, gallery),
         {:ok, publication} <- Galleries.publish_gallery(gallery) do
      conn
      |> put_status(:created)
      |> send_manifest(publication.manifest, "no-store")
    else
      nil ->
        not_found(conn)

      false ->
        forbidden(conn)

      {:error, _reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Publication failed"})
    end
  end

  def unpublish(conn, %{"slug" => slug}) do
    with gallery when not is_nil(gallery) <- Galleries.get_gallery_by_slug(slug),
         true <- owns_gallery?(conn.assigns.current_user, gallery),
         {:ok, _gallery} <- Galleries.unpublish_gallery(gallery) do
      json(conn, %{ok: true})
    else
      nil ->
        not_found(conn)

      false ->
        forbidden(conn)

      {:error, _reason} ->
        conn |> put_status(:unprocessable_entity) |> json(%{error: "Unpublish failed"})
    end
  end

  defp owns_gallery?(user, gallery), do: gallery.owner_id == user.id

  defp send_manifest(conn, manifest, cache_control) do
    etag = :crypto.hash(:sha256, Jason.encode!(manifest)) |> Base.encode16(case: :lower)

    conn
    |> put_resp_header("cache-control", cache_control)
    |> put_resp_header("etag", ~s("#{etag}"))
    |> json(manifest)
  end

  defp not_found(conn),
    do: conn |> put_status(:not_found) |> json(%{error: "Exhibition not found"})

  defp forbidden(conn), do: conn |> put_status(:forbidden) |> json(%{error: "Not gallery owner"})
end
