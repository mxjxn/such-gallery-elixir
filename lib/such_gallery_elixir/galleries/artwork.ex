defmodule SuchGalleryElixir.Galleries.Artwork do
  @moduledoc """
  Reusable artwork metadata loaded from URLs or external listings.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "artworks" do
    field :artwork_url, :string
    field :title, :string
    field :artist, :string
    field :external_id, :string
    field :aspect_ratio, :float

    has_many :placements, SuchGalleryElixir.Galleries.ArtworkPlacement

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(artwork, attrs) do
    artwork
    |> cast(attrs, [:artwork_url, :title, :artist, :external_id, :aspect_ratio])
    |> validate_required([:artwork_url])
    |> validate_number(:aspect_ratio, greater_than: 0)
    |> unique_constraint(:external_id)
  end
end
