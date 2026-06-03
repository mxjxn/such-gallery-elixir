defmodule SuchGalleryElixir.Galleries.Artwork do
  @moduledoc """
  Reusable artwork loaded from an image URL, NFT on-chain reference, or auction listing.

  ## Source types

  - `url` — plain image URL. Metadata fetched from OG tags.
  - `nft_ref` — direct NFT reference (`chain:contract:token_id`). Metadata from on-chain tokenURI.
  - `auction_listing` — auction house listing. Includes listing context in `listing_meta`.

  ## Metadata flow

  Artworks start as `:pending` with only the raw URL/ref. Metadata is resolved
  asynchronously after placement via `ArtworkResolver`. The resolver updates the
  record to `:resolved` (or `:failed`) with title, description, image, animation_url,
  and listing_meta if applicable.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @source_types [:url, :nft_ref, :auction_listing]
  @metadata_statuses [:pending, :resolved, :failed]

  schema "artworks" do
    field :artwork_url, :string
    field :title, :string
    field :artist, :string
    field :external_id, :string
    field :aspect_ratio, :float
    field :description, :string
    field :animation_url, :string

    field :source_type, Ecto.Enum, values: @source_types, default: :url
    field :source_ref, :string
    field :metadata_status, Ecto.Enum, values: @metadata_statuses, default: :pending
    field :listing_meta, :map

    has_many :placements, SuchGalleryElixir.Galleries.ArtworkPlacement

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(artwork, attrs) do
    artwork
    |> cast(attrs, [
      :artwork_url,
      :title,
      :artist,
      :external_id,
      :aspect_ratio,
      :description,
      :animation_url,
      :source_type,
      :source_ref,
      :metadata_status,
      :listing_meta
    ])
    |> validate_required([:artwork_url, :source_type])
    |> validate_number(:aspect_ratio, greater_than: 0)
    |> unique_constraint(:external_id)
    |> unique_constraint(:source_ref)
  end

  @doc """
  Changeset for updating metadata after resolution.
  """
  def metadata_changeset(artwork, attrs) do
    artwork
    |> cast(attrs, [
      :title,
      :artist,
      :description,
      :animation_url,
      :artwork_url,
      :aspect_ratio,
      :metadata_status,
      :listing_meta
    ])
  end
end
