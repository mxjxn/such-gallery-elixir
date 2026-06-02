defmodule SuchGalleryElixir.Galleries.ChatMessage do
  @moduledoc """
  Ephemeral room chat persisted per gallery for recent history on page load.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_messages" do
    field :guest_name, :string
    field :body, :string

    belongs_to :gallery, SuchGalleryElixir.Galleries.Gallery

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  def changeset(chat_message, attrs) do
    chat_message
    |> cast(attrs, [:guest_name, :body, :gallery_id])
    |> validate_required([:guest_name, :body, :gallery_id])
    |> validate_length(:body, min: 1, max: 500)
  end
end
