defmodule SuchGalleryElixir.Accounts.User do
  @moduledoc """
  A visitor or gallery owner identified by Ethereum wallet address.

  SIWE authentication comes in Phase 3; for now rows can be created on join.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :wallet_address, :string
    field :display_name, :string
    field :avatar_color, :string

    has_many :galleries, SuchGalleryElixir.Galleries.Gallery, foreign_key: :owner_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:wallet_address, :display_name, :avatar_color])
    |> validate_required([:wallet_address])
    |> unique_constraint(:wallet_address)
    |> validate_length(:wallet_address, is: 42)
    |> validate_length(:display_name, max: 100)
    |> validate_format(:avatar_color, ~r/^#[0-9A-Fa-f]{6}$/,
      message: "must be a hex color like #ff5500"
    )
  end
end
