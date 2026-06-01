defmodule SuchGalleryElixir.Galleries.ArtworkPlacement do
  @moduledoc """
  Joins an artwork to a gallery in a predefined slot or as an optional extra.

  Slot placements reference `layout_slot_id`; extras use override coordinates.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(slot extra)a
  @walls ~w(back left right)a

  schema "artwork_placements" do
    field :kind, Ecto.Enum, values: @kinds
    field :display_order, :integer
    field :override_wall, Ecto.Enum, values: @walls
    field :override_u, :float
    field :override_v, :float
    field :override_rotation_y, :float
    field :override_scale, :float

    belongs_to :gallery, SuchGalleryElixir.Galleries.Gallery
    belongs_to :artwork, SuchGalleryElixir.Galleries.Artwork
    belongs_to :layout_slot, SuchGalleryElixir.Galleries.LayoutSlot

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(placement, attrs) do
    placement
    |> cast(attrs, [
      :kind,
      :display_order,
      :gallery_id,
      :artwork_id,
      :layout_slot_id,
      :override_wall,
      :override_u,
      :override_v,
      :override_rotation_y,
      :override_scale
    ])
    |> validate_required([:kind, :display_order, :gallery_id, :artwork_id])
    |> validate_kind_fields()
    |> foreign_key_constraint(:gallery_id)
    |> foreign_key_constraint(:artwork_id)
    |> foreign_key_constraint(:layout_slot_id)
    |> unique_constraint([:gallery_id, :layout_slot_id])
  end

  defp validate_kind_fields(changeset) do
    case get_field(changeset, :kind) do
      :slot ->
        changeset
        |> validate_required([:layout_slot_id])
        |> validate_absence_of_overrides()

      :extra ->
        changeset
        |> validate_required([:override_wall, :override_u, :override_v])
        |> validate_number(:override_u, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
        |> validate_number(:override_v, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
        |> validate_optional_override_scale()
        |> validate_layout_slot_absent()

      _ ->
        changeset
    end
  end

  defp validate_absence_of_overrides(changeset) do
    Enum.reduce(
      [:override_wall, :override_u, :override_v, :override_rotation_y, :override_scale],
      changeset,
      fn field, acc ->
        if is_nil(get_field(acc, field)) do
          acc
        else
          add_error(acc, field, "must be empty for slot placements")
        end
      end
    )
  end

  defp validate_layout_slot_absent(changeset) do
    if is_nil(get_field(changeset, :layout_slot_id)) do
      changeset
    else
      add_error(changeset, :layout_slot_id, "must be empty for extra placements")
    end
  end

  defp validate_optional_override_scale(changeset) do
    case get_field(changeset, :override_scale) do
      nil -> changeset
      _ -> validate_number(changeset, :override_scale, greater_than: 0)
    end
  end
end
