defmodule SuchGalleryElixir.Repo do
  @moduledoc """
  Ecto repository for PostgreSQL.

  All gallery, room, artwork, and user persistence goes through this module.
  """

  use Ecto.Repo,
    otp_app: :such_gallery_elixir,
    adapter: Ecto.Adapters.Postgres
end
