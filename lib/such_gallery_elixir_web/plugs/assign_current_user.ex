defmodule SuchGalleryElixirWeb.Plugs.AssignCurrentUser do
  @moduledoc """
  Assigns current_user if authenticated, but does not halt.
  Use on pages that work for both visitors and authenticated users.
  """

  import Plug.Conn
  alias SuchGalleryElixir.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :user_id) do
      nil -> conn
      user_id ->
        case Accounts.get_user(user_id) do
          nil -> conn
          user -> assign(conn, :current_user, user)
        end
    end
  end
end
