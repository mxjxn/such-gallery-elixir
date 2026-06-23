defmodule SuchGalleryElixir.Accounts do
  @moduledoc """
  Context for user accounts and SIWE authentication.
  """

  alias SuchGalleryElixir.Repo
  alias SuchGalleryElixir.Accounts.User

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
  """
  def get_or_create_user(address) do
    address = String.downcase(address)

    case get_user_by_address(address) do
      nil ->
        %User{}
        |> User.changeset(%{
          wallet_address: address,
          display_name: truncate_address(address),
          avatar_color: random_color()
        })
        |> Ecto.Changeset.put_change(:wallet_address, address)
        |> Repo.insert()

      user ->
        {:ok, user}
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
    # Ensure the address in the SIWE message is EIP-55 checksummed.
    # Some wallet extensions (zilPay, etc.) return non-checksummed addresses
    # which causes the siwe parser to reject the message.
    message = checksum_message_address(message)

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

  # In a SIWE message, the address is on line 2 (0-indexed: index 1).
  # Format: "domain wants you to sign in with your Ethereum account:\n0xADDRESS\n..."
  # We extract the address, checksum it, and replace it in the message.
  defp checksum_message_address(message) do
    case String.split(message, "\n", parts: 3) do
      [header, address_line | rest] ->
        address_line = String.trim(address_line)
        if String.match?(address_line, ~r/^0x[0-9a-fA-F]{40}$/) do
          checksummed = Siwe.checksum_address(address_line)
          Enum.join([header, checksummed | rest], "\n")
        else
          message
        end
      _ ->
        message
    end
  end

  @doc """
  Generates a SIWE nonce for authentication challenge.
  """
  def generate_nonce, do: Siwe.generate_nonce()

  defp truncate_address(address) do
    "0x" <> String.slice(address, 2, 4) <> "..." <> String.slice(address, -4, 4)
  end

  defp random_color do
    "#" <>
      (for _ <- 1..3, into: "" do
        Integer.to_string(:rand.uniform(256) - 1, 16) |> String.pad_leading(2, "0")
      end)
  end
end
