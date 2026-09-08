defmodule SuchGalleryElixir.Galleries.GalleryPublication do
  @moduledoc """
  An immutable, versioned snapshot of a gallery for public consumers.

  The gallery points at its current revision. Older rows remain addressable so
  casts and other external references keep rendering the exhibition they cited.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "gallery_publications" do
    field(:revision, :integer)
    field(:manifest, :map)
    field(:published_at, :utc_datetime_usec)

    belongs_to(:gallery, SuchGalleryElixir.Galleries.Gallery)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  def changeset(publication, attrs) do
    publication
    |> cast(attrs, [:gallery_id, :revision, :manifest, :published_at])
    |> validate_required([:gallery_id, :revision, :manifest, :published_at])
    |> validate_number(:revision, greater_than: 0)
    |> foreign_key_constraint(:gallery_id)
    |> unique_constraint([:gallery_id, :revision])
  end
end
