defmodule SuchGalleryElixir.Galleries do
  @moduledoc """
  Context for gallery instances, templates, artworks, and slot-based placements.
  """

  import Ecto.Query, warn: false

  alias SuchGalleryElixir.Galleries.{
    Artwork,
    ArtworkPlacement,
    ChatMessage,
    Gallery,
    GalleryTemplate,
    LayoutSlot,
    PlacementResolver
  }

  alias SuchGalleryElixir.Repo

  @max_extras 4
  @default_chat_limit 30

  @gallery_preloads [
    :owner,
    template: :layout_slots,
    artwork_placements: [:artwork, :layout_slot]
  ]

  @doc """
  Fetches a gallery by slug with template, slots, placements, and artworks preloaded.
  """
  def get_gallery_by_slug(slug) when is_binary(slug) do
    Gallery
    |> where([g], g.slug == ^slug)
    |> preload(^@gallery_preloads)
    |> Repo.one()
  end

  @doc """
  Fetches a gallery by id with the same preloads as `get_gallery_by_slug/1`.
  """
  def get_gallery_by_id(id) when is_integer(id) do
    Gallery
    |> where([g], g.id == ^id)
    |> preload(^@gallery_preloads)
    |> Repo.one()
  end

  @doc """
  Builds a JSON-serializable gallery payload for channel join (includes resolved placements).
  """
  def gallery_state(%Gallery{} = gallery) do
    gallery = Repo.preload(gallery, @gallery_preloads)
    placements = list_placements(gallery)

    %{
      id: gallery.id,
      name: gallery.name,
      slug: gallery.slug,
      wall_color: gallery.wall_color,
      frame_style: gallery.frame_style,
      width: Gallery.width(gallery),
      depth: Gallery.depth(gallery),
      template: %{
        layout: gallery.template.layout,
        slot_count: gallery.template.slot_count
      },
      placements: resolve_placement_transforms(placements, gallery)
    }
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

  @doc "Lists all gallery templates."
  def list_templates do
    GalleryTemplate
    |> order_by([t], t.slug)
    |> preload(:layout_slots)
    |> Repo.all()
  end

  @doc """
  Lists all galleries with template preloaded.
  """
  def list_galleries do
    Gallery
    |> order_by([g], desc: g.inserted_at)
    |> preload(:template)
    |> Repo.all()
  end

  @doc """
  Updates a gallery with the given attributes.
  """
  def update_gallery(%Gallery{} = gallery, attrs) when is_map(attrs) do
    gallery
    |> Gallery.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Converts a name to a URL-friendly slug.

  - Downcases, replaces non-alphanumeric runs with hyphens, trims.
  - Capped at 100 characters.
  """
  def slugify_name(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> String.slice(0, 100)
  end

  def slugify_name(_), do: ""

  @doc "Creates a gallery from a template slug."
  def create_gallery(attrs, template_slug) when is_map(attrs) do
    case get_template_by_slug(template_slug) do
      nil ->
        {:error, :template_not_found}

      template ->
        # Normalize to string keys to avoid mixed-key CastError when merging
        attrs = if is_map(attrs) and not is_struct(attrs) do
          for {k, v} <- attrs, into: %{}, do: {to_string(k), v}
        else
          attrs
        end
        attrs = Map.put(attrs, "template_id", template.id)

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

  @doc """
  Returns the most recent chat messages for a gallery, oldest first (for UI).
  """
  def list_recent_chat_messages(gallery_id, limit \\ @default_chat_limit)
      when is_integer(gallery_id) and is_integer(limit) do
    ChatMessage
    |> where([m], m.gallery_id == ^gallery_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(^limit)
    |> Repo.all()
    |> Enum.reverse()
    |> Enum.map(&chat_message_to_map/1)
  end

  @doc """
  Persists a chat message and returns the map shape used by LiveView and channels.
  """
  def create_chat_message(gallery_id, guest_name, body)
      when is_integer(gallery_id) and is_binary(guest_name) and is_binary(body) do
    attrs = %{gallery_id: gallery_id, guest_name: guest_name, body: String.trim(body)}

    %ChatMessage{}
    |> ChatMessage.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} -> {:ok, chat_message_to_map(message)}
      {:error, _} = error -> error
    end
  end

  @doc "Maps a persisted chat row to the realtime/UI message shape."
  def chat_message_to_map(%ChatMessage{} = message) do
    %{
      name: message.guest_name,
      text: message.body,
      at: DateTime.to_iso8601(message.inserted_at)
    }
  end

  def chat_message_to_map(%{name: _, text: _, at: _} = message), do: message

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
