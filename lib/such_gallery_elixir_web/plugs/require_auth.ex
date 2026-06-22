defmodule SuchGalleryElixirWeb.Plugs.RequireAuth do
  @moduledoc """
  Plug that requires a wallet-authenticated user.
  Reads `user_id` from session and assigns `current_user`.
  """

  import Plug.Conn
  alias SuchGalleryElixir.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :user_id) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Authentication required"})
        |> halt()

      user_id ->
        case Accounts.get_user(user_id) do
          nil ->
            conn
            |> delete_session(:user_id)
            |> put_status(:unauthorized)
            |> Phoenix.Controller.json(%{error: "User not found"})
            |> halt()

          user ->
            assign(conn, :current_user, user)
        end
    end
  end
end
