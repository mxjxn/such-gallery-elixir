defmodule SuchGalleryElixir.Galleries.AlchemyClient do
  @moduledoc """
  HTTP client for the Alchemy NFT API (v3 getNFTs, v1 getNFTMetadata).

  Used for wallet browsing (paginated NFT list) and direct NFT metadata
  lookups by chain + contract + tokenId.
  """

  @http_timeout 15_000

  @doc """
  Fetches NFTs owned by an address on a given chain.

  Returns `{:ok, %{owned_nfts: [map], page_key: binary | nil, token_count: integer}}`
  or `{:error, reason}`.

  `page_key` is the cursor for the next page (nil if no more).
  """
  @spec get_nfts_for_owner(String.t(), integer(), String.t() | nil) ::
          {:ok, map()} | {:error, term()}
  def get_nfts_for_owner(owner, chain_id, page_key \\ nil) do
    params = %{
      "owner" => owner,
      "chain" => chain_to_network(chain_id),
      "pageSize" => 24,
      "contentType" => ["image", "video"]
    }

    params =
      if page_key do
        Map.put(params, "pageKey", page_key)
      else
        params
      end

    case alchemy_request("getNFTs", params) do
      {:ok, %{"ownedNfts" => nfts} = resp} ->
        {:ok,
         %{
           owned_nfts: Enum.map(nfts, &normalize_owned_nft/1),
           page_key: resp["pageKey"],
           token_count: resp["tokenCount"]
         }}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Fetches metadata for a single NFT by chain, contract address, and token ID.

  Returns `{:ok, map}` with normalized metadata or `{:error, reason}`.
  """
  @spec get_nft_metadata(String.t(), integer(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def get_nft_metadata(contract, chain_id, token_id) do
    params = %{
      "contractAddress" => contract,
      "chain" => chain_to_network(chain_id),
      "tokenId" => token_id,
      "tokenType" => "ERC721"
    }

    case alchemy_request("getNFTMetadata", params) do
      {:ok, raw} -> {:ok, normalize_nft_metadata(raw, contract, chain_id, token_id)}
      {:error, _} = err -> err
    end
  end

  # ── HTTP layer ───────────────────────────────────────────────

  defp alchemy_request(method, params) do
    api_key = Application.get_env(:such_gallery_elixir, :alchemy_api_key) ||
      raise "ALCHEMY_API_KEY not configured"

    payload =
      %{
        "jsonrpc" => "2.0",
        "method" => "alchemy_#{method}",
        "id" => 1,
        "params" => [params]
      }
      |> Jason.encode!()

    headers = [{"Content-Type", "application/json"}]
    url = "https://eth-#{chain_param(params["chain"])}.g.alchemy.com/v2/#{api_key}"

    case :httpc.request(
           :post,
           {String.to_charlist(url), headers, ~c"application/json", payload},
           [{:timeout, @http_timeout}],
           []
         ) do
      {:ok, {{_, 200, _}, _, body}} ->
        case Jason.decode(to_string(body)) do
          {:ok, %{"result" => result}} -> {:ok, result}
          {:ok, %{"error" => error}} -> {:error, {:alchemy_error, error}}
          _ -> {:error, :invalid_response}
        end

      {:ok, {{_, code, _}, _, _}} ->
        {:error, {:http_error, code}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  # Alchemy URL format uses the network name, not chain ID
  defp chain_param(network) do
    case network do
      "eth-mainnet" -> "mainnet"
      "base-mainnet" -> "base-mainnet"
      n -> String.replace(n, "-mainnet", "-mainnet")
    end
  end

  # ── Chain helpers ─────────────────────────────────────────────

  defp chain_to_network(1), do: "eth-mainnet"
  defp chain_to_network(8453), do: "base-mainnet"
  defp chain_to_network(137), do: "polygon-mainnet"
  defp chain_to_network(10), do: "opt-mainnet"
  defp chain_to_network(42161), do: "arb-mainnet"
  defp chain_to_network(chain), do: "eth-#{chain}"

  # ── Normalization ───────────────────────────────────────────

  defp normalize_owned_nft(raw) do
    contract = get_in(raw, ["contract", "address"]) || ""
    token_id = raw["tokenId"] || ""
    chain_id = raw["chain"] |> chain_from_network()

    %{
      contract: String.downcase(contract),
      token_id: token_id,
      chain_id: chain_id,
      title: raw["title"] || raw["name"] || "",
      description: raw["description"] || "",
      image_url: get_in(raw, ["media", 0, "gateway"]) ||
                 get_in(raw, ["media", 0, "thumbnailUrl"]) ||
                 get_in(raw, ["media", 0, "raw"]) ||
                 "",
      collection: raw["contract"]["name"] || "",
      collection_image: get_in(raw, ["contract", "imageUrl"]) || "",
      token_spec: get_in(raw, ["contract", "tokenType"]) || "",
      metadata_url: get_in(raw, ["tokenUri", "gateway"]) || get_in(raw, ["tokenUri", "raw"]) || ""
    }
  end

  defp normalize_nft_metadata(raw, contract, chain_id, token_id) do
    %{
      contract: String.downcase(contract),
      token_id: token_id,
      chain_id: chain_id,
      title: raw["title"] || raw["name"] || "",
      description: raw["description"] || "",
      image_url: get_in(raw, ["media", "gateway"]) ||
                 get_in(raw, ["media", "raw"]) ||
                 get_in(raw, ["image", "cachedUrl"]) ||
                 get_in(raw, ["image", "imageUrl"]) ||
                 get_in(raw, ["image", "thumbnailUrl"]) ||
                 raw["imageUri"] ||
                 "",
      collection: get_in(raw, ["contract", "name"]) || "",
      collection_image: get_in(raw, ["contract", "imageUrl"]) || "",
      token_spec: get_in(raw, ["contract", "tokenType"]) || "",
      metadata_url: get_in(raw, ["tokenUri", "gateway"]) || get_in(raw, ["tokenUri", "raw"]) || "",
      time_last_updated: raw["timeLastUpdated"] || ""
    }
  end

  defp chain_from_network("eth-mainnet"), do: 1
  defp chain_from_network("base-mainnet"), do: 8453
  defp chain_from_network("polygon-mainnet"), do: 137
  defp chain_from_network("opt-mainnet"), do: 10
  defp chain_from_network("arb-mainnet"), do: 42161
  defp chain_from_network(_), do: 1
end
