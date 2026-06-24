defmodule SuchGalleryElixirWeb.Controllers.API.ArtworkController do
  @moduledoc """
  JSON API endpoints for artwork lookup and resolution, used by the
  curation LiveView's JS client to fetch NFT data without full page reloads.
  """

  use SuchGalleryElixirWeb, :controller

  alias SuchGalleryElixir.Galleries.Lookup

  action_fallback SuchGalleryElixirWeb.Controllers.API.ArtworkFallback

  @doc """
  Resolves a raw input string (URL, NFT ref, cryptoart.social link).

  POST /api/artwork/resolve
  Body: { "input": "https://cryptoart.social/listing/123" }
  """
  def resolve(conn, %{"input" => input}) when is_binary(input) do
    case Lookup.resolve(input) do
      {:ok, data} -> json(conn, %{ok: true, data: data})
      {:error, reason} -> json(conn, %{ok: false, error: inspect(reason)})
    end
  end

  @doc """
  Browses NFTs owned by a wallet address.

  GET /api/artwork/browse?address=0x...&chain=8453&page_key=...
  """
  def browse(conn, %{"address" => address, "chain" => chain_id}) do
    page_key = conn.params["page_key"]
    chain = if is_binary(chain_id), do: String.to_integer(chain_id), else: chain_id

    case Lookup.browse_wallet(address, chain, page_key) do
      {:ok, data} -> json(conn, %{ok: true, nfts: data.nfts, page_key: data.page_key, total: data.total})
      {:error, reason} -> json(conn, %{ok: false, error: inspect(reason)})
    end
  end

  @doc """
  Direct NFT lookup by contract, chain, and token ID.

  GET /api/artwork/lookup?contract=0x...&chain=1&token_id=42
  """
  def lookup(conn, %{"contract" => contract, "chain" => chain_id, "token_id" => token_id}) do
    chain = if is_binary(chain_id), do: String.to_integer(chain_id), else: chain_id

    case Lookup.direct_lookup(contract, to_string(chain), token_id) do
      {:ok, data} -> json(conn, %{ok: true, data: data})
      {:error, reason} -> json(conn, %{ok: false, error: inspect(reason)})
    end
  end
end

defmodule SuchGalleryElixirWeb.Controllers.API.ArtworkFallback do
  @moduledoc false
  use SuchGalleryElixirWeb, :controller

  def call(conn, {:error, reason}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{ok: false, error: inspect(reason)})
  end
end
