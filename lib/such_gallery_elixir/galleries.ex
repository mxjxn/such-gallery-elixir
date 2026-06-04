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
  alias SuchGalleryElixir.Galleries.InputParser
  alias SuchGalleryElixir.Galleries.ArtworkResolver

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

  @doc """
  Deletes a gallery and all its placements and chat messages.

  Artwork records are not deleted — they may be shared across galleries.
  The cascade is handled by `on_delete: :delete_all` foreign keys.
  """
  def delete_gallery(%Gallery{} = gallery) do
    Repo.delete(gallery)
  end

  @doc "Creates an artwork record."
  def create_artwork(attrs) when is_map(attrs) do
    %Artwork{}
    |> Artwork.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Places a collection of artworks into a gallery's available template slots.

  Takes a list of raw input strings (URLs, NFT refs, or auction listing refs)
  and fills empty gallery slots in template order. Duplicates are skipped by
  `source_ref`. Inputs beyond available slots are silently truncated.

  Metadata is resolved asynchronously after placement — artworks start as
  `:pending` and are updated in the background by `ArtworkResolver`.

  Returns `{:ok, %{placed: [artwork], skipped: [source_ref]}}`.
  """
  def place_collection(%Gallery{} = gallery, inputs) when is_list(inputs) do
    # 1. Find free slots
    free_slots = list_free_slots(gallery)
    free_count = length(free_slots)

    if free_count == 0 do
      {:ok, %{placed: [], skipped: Enum.map(inputs, &elem(InputParser.parse(&1), 1) |> elem(1))}}
    else
      # 2. Parse and dedup inputs
      parsed =
        inputs
        |> Enum.map(&InputParser.parse/1)
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, {type, ref}} -> {type, ref} end)
        |> Enum.uniq_by(fn {_type, ref} -> ref end)
        |> Enum.take(free_count)

      # 3. Place each
      {placed, skipped} =
        Enum.reduce(parsed, {[], []}, fn {source_type, source_ref}, {placed_acc, skipped_acc} ->
          # Check if artwork with this source_ref already exists
          existing = Repo.get_by(Artwork, source_ref: source_ref)

          artwork =
            case existing do
              nil ->
                # Create new artwork with pending status
                initial_url = if source_type == :url, do: source_ref, else: nil

                {:ok, art} =
                  create_artwork(%{
                    artwork_url: initial_url,
                    source_type: source_type,
                    source_ref: source_ref,
                    external_id: nft_identity(source_type, source_ref),
                    metadata_status: :pending
                  })

                art

              art ->
                art
            end

          # Find next free slot
          slot = find_next_free_slot(gallery, placed_acc, free_slots)

          case slot do
            nil ->
              {placed_acc, [source_ref | skipped_acc]}

            %LayoutSlot{} = slot ->
              display_order = length(placed_acc) + 1

              case assign_artwork_to_slot(gallery, artwork, slot, display_order) do
                {:ok, _placement} ->
                  # Kick off async metadata resolve
                  Task.start_link(fn ->
                    ArtworkResolver.resolve(artwork)
                  end)

                  {[{artwork, source_ref, slot} | placed_acc], skipped_acc}

                {:error, _reason} ->
                  {placed_acc, [source_ref | skipped_acc]}
              end
          end
        end)

      {:ok, %{placed: placed |> Enum.reverse() |> Enum.map(fn {art, ref, _slot} -> %{artwork: art, source_ref: ref} end), skipped: skipped}}
    end
  end

  # Derive the dedup-safe external_id from source type and ref.
  # For NFTs and auction listings, it's the chain:contract:token_id part.
  # For URLs, it's the URL itself.
  defp nft_identity(:url, ref), do: ref
  defp nft_identity(:nft_ref, ref), do: ref

  defp nft_identity(:auction_listing, ref) do
    # auction:chain:contract:token_id:listing_id → chain:contract:token_id
    ref
    |> String.split(":")
    |> case do
      [_auction, chain, contract, token_id, _listing_id] ->
        "#{chain}:#{contract}:#{token_id}"

      _ ->
        ref
    end
  end

  defp list_free_slots(%Gallery{template_id: template_id, id: gallery_id}) do
    occupied_slot_ids =
      ArtworkPlacement
      |> where([p], p.gallery_id == ^gallery_id and not is_nil(p.layout_slot_id))
      |> select([p], p.layout_slot_id)
      |> Repo.all()

    LayoutSlot
    |> where([s], s.template_id == ^template_id and s.id not in ^occupied_slot_ids)
    |> order_by([s], s.slot_index)
    |> Repo.all()
  end

  defp find_next_free_slot(%Gallery{}, placed_acc, free_slots) do
    # Get slots already used in this batch
    used_slot_ids =
      placed_acc
      |> Enum.map(fn {_art, _ref, %LayoutSlot{id: id}} -> id end)

    Enum.find(free_slots, fn %LayoutSlot{id: id} -> id not in used_slot_ids end)
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
