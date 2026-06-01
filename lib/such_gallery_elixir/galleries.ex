defmodule SuchGalleryElixir.Galleries do
  @moduledoc """
  Context for gallery instances, templates, artworks, and slot-based placements.
  """

  import Ecto.Query, warn: false

  alias SuchGalleryElixir.Galleries.{
    Artwork,
    ArtworkPlacement,
    Gallery,
    GalleryTemplate,
    LayoutSlot,
    PlacementResolver
  }

  alias SuchGalleryElixir.Repo

  @max_extras 4

  @doc """
  Fetches a gallery by slug with template, slots, placements, and artworks preloaded.
  """
  def get_gallery_by_slug(slug) when is_binary(slug) do
    Gallery
    |> where([g], g.slug == ^slug)
    |> preload([
      :owner,
      template: :layout_slots,
      artwork_placements: [:artwork, :layout_slot]
    ])
    |> Repo.one()
  end

  @doc "Lists placements for a gallery ordered for magazine mode."
  def list_placements(%Gallery{id: gallery_id}) do
    ArtworkPlacement
    |> where([p], p.gallery_id == ^gallery_id)
    |> order_by([p], asc: p.display_order)
    |> preload([:artwork, :layout_slot])
    |> Repo.all()
  end

  @doc """
  Assigns an artwork to a predefined layout slot on a gallery.
  """
  def assign_artwork_to_slot(%Gallery{} = gallery, %Artwork{} = artwork, %LayoutSlot{} = slot, display_order)
      when is_integer(display_order) do
    with :ok <- ensure_slot_belongs_to_gallery(gallery, slot),
         :ok <- ensure_slot_available(gallery, slot) do
      %ArtworkPlacement{}
      |> ArtworkPlacement.changeset(%{
        kind: :slot,
        gallery_id: gallery.id,
        artwork_id: artwork.id,
        layout_slot_id: slot.id,
        display_order: display_order
      })
      |> Repo.insert()
    end
  end

  @doc """
  Adds an extra placement with explicit wall coordinates (max #{@max_extras} per gallery).
  """
  def add_extra(%Gallery{} = gallery, %Artwork{} = artwork, attrs) when is_map(attrs) do
    with :ok <- ensure_extra_capacity(gallery) do
      attrs =
        attrs
        |> Map.put(:kind, :extra)
        |> Map.put(:gallery_id, gallery.id)
        |> Map.put(:artwork_id, artwork.id)

      %ArtworkPlacement{}
      |> ArtworkPlacement.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc "Resolves world-space transforms for placements in a preloaded gallery."
  def resolve_placement_transforms(placements, %Gallery{} = gallery) when is_list(placements) do
    PlacementResolver.resolve_all(placements, gallery)
  end

  @doc "Fetches a gallery template by slug."
  def get_template_by_slug(slug) when is_binary(slug) do
    GalleryTemplate
    |> where([t], t.slug == ^slug)
    |> preload(:layout_slots)
    |> Repo.one()
  end

  @doc "Creates a gallery from a template slug."
  def create_gallery(attrs, template_slug) when is_map(attrs) do
    case get_template_by_slug(template_slug) do
      nil ->
        {:error, :template_not_found}

      template ->
        attrs = Map.put(attrs, :template_id, template.id)

        %Gallery{}
        |> Gallery.changeset(attrs)
        |> Repo.insert()
    end
  end

  @doc "Creates an artwork record."
  def create_artwork(attrs) when is_map(attrs) do
    %Artwork{}
    |> Artwork.changeset(attrs)
    |> Repo.insert()
  end

  defp ensure_slot_belongs_to_gallery(%Gallery{template_id: template_id}, %LayoutSlot{template_id: template_id}),
    do: :ok

  defp ensure_slot_belongs_to_gallery(_, _),
    do: {:error, :slot_template_mismatch}

  defp ensure_slot_available(%Gallery{id: gallery_id}, %LayoutSlot{id: slot_id}) do
    case Repo.get_by(ArtworkPlacement, gallery_id: gallery_id, layout_slot_id: slot_id) do
      nil -> :ok
      _ -> {:error, :slot_taken}
    end
  end

  defp ensure_extra_capacity(%Gallery{id: gallery_id}) do
    count =
      ArtworkPlacement
      |> where([p], p.gallery_id == ^gallery_id and p.kind == ^:extra)
      |> Repo.aggregate(:count)

    if count < @max_extras do
      :ok
    else
      {:error, :too_many_extras}
    end
  end
end
