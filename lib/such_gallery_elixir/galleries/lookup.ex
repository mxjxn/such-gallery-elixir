defmodule SuchGalleryElixir.Galleries.Lookup do
  @moduledoc """
  Unified lookup resolver for the curation page.

  Routes a user's input through the appropriate resolution path:
  - cryptoart.social URL → subgraph listing → Alchemy metadata
  - NFT reference → Alchemy metadata
  - Plain image URL → accepted directly

  Returns a normalized artwork map suitable for display and placement.
  """

  alias SuchGalleryElixir.Galleries.{InputParser, SubgraphClient, AlchemyClient}

  @doc """
  Resolves a raw input string (URL, NFT ref, cryptoart.social link) into
  a normalized artwork data map.

  Returns `{:ok, map}` or `{:error, reason}`.
  """
  @spec resolve(String.t()) :: {:ok, map()} | {:error, term()}
  def resolve(input) do
    case InputParser.parse(input) do
      {:ok, {:listing_url, url}} ->
        resolve_cryptoart_listing(url)

      {:ok, {:nft_ref, _ref}} ->
        resolve_nft_ref(input)

      {:ok, {:auction_listing, ref}} ->
        resolve_auction_listing(ref)

      {:ok, {:url, url}} ->
        {:ok, %{
          source_type: :url,
          source_ref: url,
          title: "",
          image_url: url,
          chain_id: nil,
          contract: nil,
          token_id: nil,
          collection: ""
        }}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Resolves a cryptoart.social listing URL via subgraph + Alchemy.

  Returns `{:ok, map}` with full NFT metadata or `{:error, reason}`.
  """
  @spec resolve_cryptoart_listing(String.t()) :: {:ok, map()} | {:error, term()}
  def resolve_cryptoart_listing(url) do
    case InputParser.parse_cryptoart_url(url) do
      {:ok, %{listing_id: listing_id, chain_id: chain_id}} ->
        with {:ok, listing} <- SubgraphClient.get_listing(listing_id, chain_id) do
          # Now fetch full NFT metadata from Alchemy using listing data
          AlchemyClient.get_nft_metadata(
            listing.token_address,
            chain_id,
            listing.token_id
          )
        end

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Resolves an NFT ref (nft:chain:contract:tokenId) via Alchemy.

  Returns `{:ok, map}` or `{:error, reason}`.
  """
  @spec resolve_nft_ref(String.t()) :: {:ok, map()} | {:error, term()}
  def resolve_nft_ref(ref) do
    with {:ok, {:nft_ref, _}} <- InputParser.parse(ref),
         [_, chain_str, contract, token_id] <- String.split(ref, ":"),
         {chain_id, ""} <- Integer.parse(chain_str) do
      AlchemyClient.get_nft_metadata(contract, chain_id, token_id)
    else
      {:error, _} = err -> err
      _ -> {:error, :invalid_nft_ref}
    end
  end

  @doc """
  Resolves an auction listing ref via subgraph + Alchemy.
  """
  @spec resolve_auction_listing(String.t()) :: {:ok, map()} | {:error, term()}
  def resolve_auction_listing(ref) do
    with [_, chain_str, _contract, _token_id, listing_id_str] <- String.split(ref, ":"),
         {chain_id, ""} <- Integer.parse(chain_str),
         {listing_id, ""} <- Integer.parse(listing_id_str) do
      with {:ok, listing} <- SubgraphClient.get_listing(listing_id, chain_id) do
        AlchemyClient.get_nft_metadata(
          listing.token_address,
          chain_id,
          listing.token_id
        )
      end
    else
      _ -> {:error, :invalid_auction_format}
    end
  end

  @doc """
  Fetches NFTs for a wallet address. Used by the "Browse Wallet" tab.

  Returns `{:ok, %{nfts: [map], page_key: binary | nil, total: integer}}`.
  """
  @spec browse_wallet(String.t(), integer(), String.t() | nil) ::
          {:ok, map()} | {:error, term()}
  def browse_wallet(address, chain_id, page_key \\ nil) do
    address = String.trim(address) |> String.downcase()

    if String.match?(address, ~r/^0x[a-fA-F0-9]{40}$/) do
      case AlchemyClient.get_nfts_for_owner(address, chain_id, page_key) do
        {:ok, %{owned_nfts: nfts} = resp} ->
          {:ok, %{nfts: nfts, page_key: resp[:page_key], total: resp[:token_count]}}

        {:error, _} = err ->
          err
      end
    else
      {:error, :invalid_address}
    end
  end

  @doc """
  Direct NFT lookup by chain + contract + tokenId.
  Used by the "Direct Lookup" tab.

  Returns `{:ok, map}` or `{:error, reason}`.
  """
  @spec direct_lookup(String.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def direct_lookup(contract, chain_str, token_id) do
    contract = String.trim(contract) |> String.downcase()
    chain_str = String.trim(chain_str)
    token_id = String.trim(token_id)

    with {chain_id, ""} <- Integer.parse(chain_str),
         :ok <- validate_address(contract),
         :ok <- validate_nonempty(token_id) do
      AlchemyClient.get_nft_metadata(contract, chain_id, token_id)
    else
      _ -> {:error, :invalid_params}
    end
  end

  defp validate_address(addr) do
    if String.match?(addr, ~r/^0x[a-fA-F0-9]{1,64}$/), do: :ok, else: {:error, :invalid_address}
  end

  defp validate_nonempty(str) do
    if str == "", do: {:error, :empty}, else: :ok
  end
end
