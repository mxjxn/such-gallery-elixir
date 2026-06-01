defmodule SuchGalleryElixir.Galleries.ArtworkPlacement do
  @moduledoc """
  A single piece of art hung on a wall with position, rotation, and scale in room space.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @walls ~w(back left right)a

  schema "artwork_placements" do
    field :artwork_url, :string
    field :title, :string
    field :artist, :string
    field :position_x, :float, default: 0.0
    field :position_y, :float, default: 0.0
    field :position_z, :float, default: 0.0
    field :rotation, :float, default: 0.0
    field :scale, :float, default: 1.0
    field :wall, Ecto.Enum, values: @walls, default: :back

    belongs_to :room, SuchGalleryElixir.Galleries.Room

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(placement, attrs) do
    placement
    |> cast(attrs, [
      :artwork_url,
      :title,
      :artist,
      :position_x,
      :position_y,
      :position_z,
      :rotation,
      :scale,
      :wall,
      :room_id
    ])
    |> validate_required([:artwork_url, :wall, :room_id])
    |> validate_number(:scale, greater_than: 0)
    |> foreign_key_constraint(:room_id)
  end
end
