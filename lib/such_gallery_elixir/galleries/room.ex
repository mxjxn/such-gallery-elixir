defmodule SuchGalleryElixir.Galleries.Room do
  @moduledoc """
  Physical layout for a gallery: dimensions and floor plan used to generate 3D geometry.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @layouts ~w(rectangular l_shaped open_plan)a

  schema "rooms" do
    field :layout, Ecto.Enum, values: @layouts, default: :rectangular
    field :width, :float
    field :depth, :float

    belongs_to :gallery, SuchGalleryElixir.Galleries.Gallery
    has_many :artwork_placements, SuchGalleryElixir.Galleries.ArtworkPlacement

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:layout, :width, :depth, :gallery_id])
    |> validate_required([:layout, :width, :depth, :gallery_id])
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:depth, greater_than: 0)
    |> foreign_key_constraint(:gallery_id)
  end
end
