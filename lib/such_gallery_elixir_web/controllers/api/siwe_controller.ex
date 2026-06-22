defmodule SuchGalleryElixirWeb.Api.SiweController do
  use SuchGalleryElixirWeb, :controller

  alias SuchGalleryElixir.Accounts

  @doc """
  POST /api/siwe/nonce — returns a fresh nonce, stores in session.
  """
  def nonce(conn, _params) do
    nonce = Accounts.generate_nonce()
    conn = put_session(conn, :siwe_nonce, nonce)
    json(conn, %{nonce: nonce})
  end

  @doc """
  POST /api/siwe/verify — verifies SIWE message + signature, sets user in session.
  Body: %{"message" => siwe_string, "signature" => hex_signature}
  """
  def verify(conn, %{"message" => message, "signature" => signature}) do
    case Accounts.verify_siwe(message, signature) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> put_session(:siwe_nonce, nil)
        |> json(%{
          address: user.wallet_address,
          display_name: user.display_name,
          avatar_color: user.avatar_color
        })

      {:error, reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Verification failed: #{inspect(reason)}"})
    end
  end

  def verify(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing message or signature"})
  end

  @doc """
  DELETE /api/siwe/session — clears session, logs out.
  """
  def logout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> json(%{ok: true})
  end

  @doc """
  GET /api/siwe/me — returns current user if authenticated.
  """
  def me(conn, _params) do
    case get_session(conn, :user_id) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})

      user_id ->
        case Accounts.get_user(user_id) do
          nil ->
            conn
            |> clear_session()
            |> put_status(:unauthorized)
            |> json(%{error: "User not found"})

          user ->
            json(conn, %{
              address: user.wallet_address,
              display_name: user.display_name,
              avatar_color: user.avatar_color
            })
        end
    end
  end
end
