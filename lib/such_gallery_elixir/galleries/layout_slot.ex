defmodule SuchGalleryElixir.Galleries.LayoutSlot do
  @moduledoc """
  A predefined frame position on a gallery template wall.

  Coordinates `u` and `v` are normalized 0..1 along the wall width and height.
  World-space transforms are computed at read time from the gallery's dimensions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @walls ~w(back left right)a

  schema "layout_slots" do
    field :slot_index, :integer
    field :wall, Ecto.Enum, values: @walls, default: :back
    field :u, :float
    field :v, :float, default: 0.5
    field :rotation_y, :float, default: 0.0
    field :scale, :float, default: 1.0

    belongs_to :template, SuchGalleryElixir.Galleries.GalleryTemplate

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(slot, attrs) do
    slot
    |> cast(attrs, [:slot_index, :wall, :u, :v, :rotation_y, :scale, :template_id])
    |> validate_required([:slot_index, :wall, :u, :v, :template_id])
    |> validate_number(:u, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_number(:v, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_number(:scale, greater_than: 0)
    |> unique_constraint([:template_id, :wall, :slot_index])
    |> foreign_key_constraint(:template_id)
  end
end
