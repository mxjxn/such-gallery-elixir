defmodule SuchGalleryElixir.Galleries.InputParser do
  @moduledoc """
  Parses raw user input into typed artwork source references.

  ## Input formats

  - **Auction listing:** `auction:{chain_id}:{contract}:{token_id}:{listing_id}`
  - **NFT reference:** `nft:{chain_id}:{contract_address}:{token_id}`
  - **Plain URL:** anything that starts with `http://` or `https://`
  - **Bare string:** rejected (ambiguous)

  Returns `{:ok, {source_type, source_ref}}` or `{:error, reason}`.
  """

  @auction_prefix "auction:"
  @nft_prefix "nft:"

  @supported_chains [1, 8453]

  @doc """
  Parses a raw input string into a source type and reference.
  """
  def parse(input) when is_binary(input) do
    input = String.trim(input)

    cond do
      input == "" ->
        {:error, :empty_input}

      String.starts_with?(input, @auction_prefix) ->
        parse_auction(input)

      String.starts_with?(input, @nft_prefix) ->
        parse_nft_ref(input)

      String.starts_with?(input, "http://") or String.starts_with?(input, "https://") ->
        {:ok, {:url, input}}

      true ->
        {:error, :invalid_input}
    end
  end

  def parse(_), do: {:error, :invalid_input}

  # Auction listing: auction:{chain}:{contract}:{token_id}:{listing_id}
  defp parse_auction(input) do
    input
    |> String.trim_leading(@auction_prefix)
    |> String.split(":")
    |> case do
      [chain, contract, token_id, listing_id] ->
        with {:ok, _chain_id} <- parse_chain_id(chain),
             :ok <- validate_address(contract),
             :ok <- validate_nonempty(token_id),
             :ok <- validate_nonempty(listing_id) do
          {:ok, {:auction_listing, "auction:#{chain}:#{String.downcase(contract)}:#{token_id}:#{listing_id}"}}
        end

      _ ->
        {:error, :invalid_auction_format}
    end
  end

  # NFT ref: nft:{chain}:{contract}:{token_id}
  defp parse_nft_ref(input) do
    input
    |> String.trim_leading(@nft_prefix)
    |> String.split(":")
    |> case do
      [chain, contract, token_id] ->
        with {:ok, chain_id} <- parse_chain_id(chain),
             :ok <- validate_address(contract),
             :ok <- validate_nonempty(token_id) do
          if chain_id in @supported_chains do
            {:ok, {:nft_ref, "nft:#{chain}:#{String.downcase(contract)}:#{token_id}"}}
          else
            {:error, :invalid_chain}
          end
        end

      _ ->
        {:error, :invalid_nft_ref}
    end
  end

  defp parse_chain_id(chain_str) do
    case Integer.parse(chain_str) do
      {n, ""} when n > 0 -> {:ok, n}
      _ -> {:error, :invalid_chain}
    end
  end

  defp validate_address(addr) do
    if String.match?(addr, ~r/^0x[a-fA-F0-9]{1,64}$/) do
      :ok
    else
      {:error, :invalid_address}
    end
  end

  defp validate_nonempty(str) do
    if str == "", do: {:error, :empty_field}, else: :ok
  end
end
