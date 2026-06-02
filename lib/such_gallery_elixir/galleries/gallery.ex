defmodule SuchGalleryElixir.Galleries.Gallery do
  @moduledoc """
  A walkable gallery instance: branding, template, and artwork placements.

  Channel topics use `room:{gallery_id}` — the gallery is the spatial unit.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @frame_styles ~w(classic minimal ornate)a

  schema "galleries" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :wall_color, :string, default: "#f5f5f0"
    field :frame_style, Ecto.Enum, values: @frame_styles, default: :classic
    field :width_override, :float
    field :depth_override, :float

    belongs_to :template, SuchGalleryElixir.Galleries.GalleryTemplate
    belongs_to :owner, SuchGalleryElixir.Accounts.User
    has_many :artwork_placements, SuchGalleryElixir.Galleries.ArtworkPlacement
    has_many :chat_messages, SuchGalleryElixir.Galleries.ChatMessage

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(gallery, attrs) do
    gallery
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :wall_color,
      :frame_style,
      :template_id,
      :width_override,
      :depth_override,
      :owner_id
    ])
    |> validate_required([:name, :slug, :wall_color, :frame_style, :template_id])
    |> validate_length(:name, max: 200)
    |> validate_length(:slug, max: 100)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/)
    |> validate_format(:wall_color, ~r/^#[0-9A-Fa-f]{6}$/)
    |> validate_optional_dimensions()
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:template_id)
    |> foreign_key_constraint(:owner_id)
  end

  @doc "Effective width for 3D placement (override or template default). Requires preloaded `:template`."
  def width(%__MODULE__{width_override: w, template: %{width: _}}) when not is_nil(w), do: w
  def width(%__MODULE__{template: %{width: t}}), do: t

  @doc "Effective depth for 3D placement (override or template default). Requires preloaded `:template`."
  def depth(%__MODULE__{depth_override: d, template: %{depth: _}}) when not is_nil(d), do: d
  def depth(%__MODULE__{template: %{depth: t}}), do: t

  defp validate_optional_dimensions(changeset) do
    changeset
    |> validate_optional_number(:width_override, greater_than: 0)
    |> validate_optional_number(:depth_override, greater_than: 0)
  end

  defp validate_optional_number(changeset, field, opts) do
    if is_nil(get_field(changeset, field)) do
      changeset
    else
      validate_number(changeset, field, opts)
    end
  end
end
