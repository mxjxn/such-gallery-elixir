defmodule SuchGalleryElixir.Accounts do
  @moduledoc """
  Context for user accounts and SIWE authentication.

  New users get their display name resolved via ENS on creation.
  Existing users with truncated addresses get ENS re-checked on
  subsequent logins (handles late ENS setup or name changes).
  """

  alias SuchGalleryElixir.Repo
  alias SuchGalleryElixir.Accounts.User
  alias SuchGalleryElixir.Accounts.EnsResolver

  @doc """
  Fetches a user by ID.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Fetches a user by wallet address (case-insensitive, stored as lowercase).
  """
  def get_user_by_address(address) do
    address = String.downcase(address)
    Repo.get_by(User, wallet_address: address)
  end

  @doc """
  Finds or creates a user by wallet address.

  New users get ENS resolution attempted — if an ENS name exists,
  it becomes their display name; otherwise they get a truncated address.
  """
  def get_or_create_user(address) do
    address = String.downcase(address)

    case get_user_by_address(address) do
      nil ->
        display_name = ens_name_or_default(address)
        color = random_color()

        %User{}
        |> User.changeset(%{
          wallet_address: address,
          display_name: display_name,
          avatar_color: color
        })
        |> Ecto.Changeset.put_change(:wallet_address, address)
        |> Repo.insert()

      user ->
        {:ok, user}
    end
  end

  @doc """
  Re-checks ENS for a user whose display_name is still a truncated address.

  Returns the updated user (or unchanged user if no ENS found).
  Call this on login to handle late ENS setup or name changes.
  """
  @spec refresh_ens(User.t()) :: User.t()
  def refresh_ens(%User{display_name: name} = user) do
    if looks_like_truncated?(name) do
      case EnsResolver.resolve_address(user.wallet_address) do
        {:ok, ens_name} ->
          user
          |> Ecto.Changeset.change(display_name: ens_name)
          |> Repo.update!()

        _ ->
          user
      end
    else
      user
    end
  end

  @doc """
  Verifies a SIWE message + signature against an expected nonce.

  The nonce is stored server-side during the challenge phase and must
  match the nonce embedded in the SIWE message — prevents replay attacks
  where a valid signature is reused with a different message.
  Also checks domain matches our configured host and verifies signature
  validity and time constraints via Siwe.parse_if_valid/2.
  """
  def verify_siwe(message, signature, expected_nonce) do
    with {:ok, parsed} <- Siwe.parse_if_valid(message, signature) do
      cond do
        parsed.nonce != expected_nonce ->
          {:error, {:nonce_mismatch}}

        parsed.domain != siwe_domain() ->
          {:error, {:domain_mismatch, parsed.domain, siwe_domain()}}

        true ->
          get_or_create_user(parsed.address)
      end
    end
  end

  defp siwe_domain do
    Application.get_env(:such_gallery_elixir, :siwe_domain, "such.gallery")
  end

  @doc """
  Generates a SIWE nonce for authentication challenge.
  """
  def generate_nonce, do: Siwe.generate_nonce()

  defp truncate_address(address) do
    "0x" <> String.slice(address, 2, 6) <> "..." <> String.slice(address, -4, 4)
  end

  defp ens_name_or_default(address) do
    case EnsResolver.resolve_address(address) do
      {:ok, ens_name} -> ens_name
      _ -> truncate_address(address)
    end
  end

  defp looks_like_truncated?(name) do
    String.starts_with?(name, "0x") and String.contains?(name, "...")
  end

  defp random_color do
    "#" <>
      (for _ <- 1..3, into: "" do
        Integer.to_string(:rand.uniform(256) - 1, 16) |> String.pad_leading(2, "0")
      end)
  end
end
