defmodule SuchGalleryElixir.Galleries.Gallery do
  @moduledoc """
  A persistent gallery space: branding, wall/frame styling, and owned rooms.

  Each gallery maps to one or more channel topics once rooms are loaded.
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

    belongs_to :owner, SuchGalleryElixir.Accounts.User
    has_many :rooms, SuchGalleryElixir.Galleries.Room

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(gallery, attrs) do
    gallery
    |> cast(attrs, [:name, :slug, :description, :wall_color, :frame_style, :owner_id])
    |> validate_required([:name, :slug, :wall_color, :frame_style])
    |> validate_length(:name, max: 200)
    |> validate_length(:slug, max: 100)
    |> validate_format(:slug, ~r/^[a-z0-9]+(?:-[a-z0-9]+)*$/,
      message: "must be lowercase letters, numbers, and hyphens"
    )
    |> validate_format(:wall_color, ~r/^#[0-9A-Fa-f]{6}$/,
      message: "must be a hex color like #f5f5f0"
    )
    |> unique_constraint(:slug)
    |> foreign_key_constraint(:owner_id)
  end
end
