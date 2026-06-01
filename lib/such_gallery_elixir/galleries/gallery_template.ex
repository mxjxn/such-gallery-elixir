defmodule SuchGalleryElixir.Galleries.GalleryTemplate do
  @moduledoc """
  A predefined gallery type (e.g. minimal_4, show_32) with fixed frame slots and default dimensions.

  Instances are `Gallery` rows that reference a template; slot geometry lives on `LayoutSlot`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @layouts ~w(rectangular l_shaped open_plan)a

  schema "gallery_templates" do
    field :slug, :string
    field :name, :string
    field :slot_count, :integer
    field :layout, Ecto.Enum, values: @layouts, default: :rectangular
    field :width, :float
    field :depth, :float

    has_many :layout_slots, SuchGalleryElixir.Galleries.LayoutSlot, foreign_key: :template_id
    has_many :galleries, SuchGalleryElixir.Galleries.Gallery, foreign_key: :template_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(template, attrs) do
    template
    |> cast(attrs, [:slug, :name, :slot_count, :layout, :width, :depth])
    |> validate_required([:slug, :name, :slot_count, :layout, :width, :depth])
    |> validate_number(:slot_count, greater_than: 0)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:depth, greater_than: 0)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:[-_][a-z0-9]+)*$/)
    |> unique_constraint(:slug)
  end
end
