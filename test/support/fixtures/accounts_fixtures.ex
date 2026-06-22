defmodule SuchGalleryElixir.AccountsFixtures do
  @moduledoc """
  Test fixtures for user accounts.
  """

  alias SuchGalleryElixir.Accounts.User
  alias SuchGalleryElixir.Repo

  def unique_wallet_address do
    "0x#{Base.encode16(:crypto.strong_rand_bytes(20), case: :lower)}"
  end

  @doc """
  Creates a user with a valid wallet address.
  """
  def user_fixture(attrs \\ %{}) do
    address = Map.get(attrs, :wallet_address, unique_wallet_address())

    {:ok, user} =
      %User{}
      |> User.changeset(
        Map.merge(
          %{
            wallet_address: address,
            display_name: "0x" <> String.slice(address, 2, 6) <> "...",
            avatar_color: "#ff5500"
          },
          attrs
        )
      )
      |> Repo.insert()

    user
  end

  @doc """
  Returns a test conn with user_id in session (simulates authenticated user).
  """
  def authed_conn(conn, user \\ nil) do
    user = user || user_fixture()
    Phoenix.ConnTest.init_test_session(conn, %{user_id: user.id})
  end
end
