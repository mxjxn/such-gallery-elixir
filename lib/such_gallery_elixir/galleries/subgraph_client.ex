defmodule SuchGalleryElixir.Galleries.SubgraphClient do
  @moduledoc """
  Queries the cryptoart auctionhouse subgraph via The Graph's gateway API.

  Fetches listing data by listing ID and chain, returning token contract,
  token ID, seller, price, and status in a single GraphQL call.
  """

  @http_timeout 10_000

  @doc """
  Fetches a single listing by listing ID for the given chain.

  Returns `{:ok, map}` with listing fields, or `{:error, reason}`.
  """
  @spec get_listing(integer(), String.t()) :: {:ok, map()} | {:error, term()}
  def get_listing(listing_id, chain_id) when is_integer(chain_id) do
    query = """
    query GetListing($listingId: String!) {
      listings(where: { listingId: $listingId }) {
        id
        chainId
        listingId
        tokenAddress
        tokenId
        tokenSpec
        listingType
        initialAmount
        totalAvailable
        totalSold
        startTime
        endTime
        erc20
        seller
        status
        hasBid
        finalized
        createdAt
      }
    }
    """

    variables = %{"listingId" => to_string(listing_id)}

    case graphql_request(query, variables, chain_id) do
      {:ok, %{"listings" => []}} -> {:error, :listing_not_found}
      {:ok, %{"listings" => [listing | _]}} -> {:ok, normalize_listing(listing)}
      {:error, _} = err -> err
    end
  end

  # ── HTTP layer ───────────────────────────────────────────────

  defp graphql_request(query, variables, chain_id) do
    url = subgraph_url(chain_id)
    api_key = api_key()

    payload =
      %{
        "query" => query,
        "variables" => variables
      }
      |> Jason.encode!()

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{api_key}"}
    ]

    case :httpc.request(
           :post,
           {String.to_charlist(url), headers, ~c"application/json", payload},
           [{:timeout, @http_timeout}],
           []
         ) do
      {:ok, {{_, 200, _}, _, body}} ->
        case Jason.decode(to_string(body)) do
          {:ok, %{"data" => data}} -> {:ok, data}
          {:ok, %{"errors" => errors}} -> {:error, {:graphql_errors, errors}}
          _ -> {:error, :invalid_response}
        end

      {:ok, {{_, code, _}, _, _}} ->
        {:error, {:http_error, code}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  defp subgraph_url(_chain_id) do
    deployment_id = Application.get_env(:such_gallery_elixir, :graph_subgraph_deployment)
    "https://gateway.thegraph.com/api/#{deployment_id}"
  end

  defp api_key do
    Application.get_env(:such_gallery_elixir, :graph_api_key) ||
      raise "GRAPH_API_KEY not configured"
  end

  # ── Normalization ───────────────────────────────────────────

  # The Graph returns BigInt fields as strings.
  defp normalize_listing(raw) do
    %{
      listing_id: raw["listingId"],
      chain_id: raw["chainId"] || 1,
      token_address: normalize_address(raw["tokenAddress"]),
      token_id: raw["tokenId"],
      token_spec: raw["tokenSpec"],
      listing_type: raw["listingType"],
      initial_amount: raw["initialAmount"],
      total_sold: raw["totalSold"],
      start_time: raw["startTime"],
      end_time: raw["endTime"],
      erc20: normalize_address(raw["erc20"]),
      seller: normalize_address(raw["seller"]),
      status: raw["status"],
      has_bid: raw["hasBid"],
      finalized: raw["finalized"]
    }
  end

  defp normalize_address(nil), do: nil
  defp normalize_address(addr) when is_binary(addr), do: String.downcase(addr)
end
