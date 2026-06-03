defmodule SuchGalleryElixir.Galleries.ArtworkResolver do
  @moduledoc """
  Resolves artwork metadata from different source types.

  Ported from cryptoart-studio's `MetadataResolver` pattern (collection-indexer).

  ## Source strategies

  - `:url` — fetch the URL, parse OG meta tags for title/description/image
  - `:nft_ref` — call `tokenURI(chain, contract, tokenId)` via RPC, fetch metadata JSON
  - `:auction_listing` — fetch listing data from auction house contract, then resolve NFT metadata

  ## IPFS resolution

  Transforms `ipfs://` and `ipfs/` URIs to gateway URLs,
  same approach as the collection-indexer `resolveUri`.
  """

  alias SuchGalleryElixir.Repo
  alias SuchGalleryElixir.Galleries.Artwork

  @ipfs_gateway Application.compile_env(:such_gallery_elixir, :ipfs_gateway, "https://ipfs.io/ipfs/")

  @rpc_timeout 10_000
  @http_timeout 15_000

  # keccak256 selectors
  @token_uri_selector "0xc87b56dd"
  @get_listing_selector "0x2b3b2423"
  @get_current_price_selector "0xf4d60adb"

  @doc """
  Resolves metadata for an artwork record. Updates it in place.

  Returns `{:ok, artwork}` on success or `{:error, reason}` on failure.
  """
  def resolve(%Artwork{source_type: :url, artwork_url: url} = artwork) when is_binary(url) do
    case fetch_url_metadata(url) do
      {:ok, meta} ->
        attrs =
          %{}
          |> maybe_put(:title, meta.title)
          |> maybe_put(:description, meta.description)
          |> maybe_put(:artist, meta.artist)
          |> maybe_put(:artwork_url, meta.image_url)
          |> maybe_put(:aspect_ratio, meta.aspect_ratio)
          |> Map.put(:metadata_status, :resolved)

        {:ok, _} = update_artwork(artwork, attrs)
        {:ok, Repo.reload(artwork)}

      {:error, reason} ->
        update_artwork(artwork, %{metadata_status: :failed})
        {:error, reason}
    end
  end

  def resolve(%Artwork{source_type: :nft_ref, source_ref: ref} = artwork) when is_binary(ref) do
    case parse_nft_ref(ref) do
      {:ok, chain_id, contract, token_id} ->
        case resolve_nft(chain_id, contract, token_id) do
          {:ok, meta} ->
            attrs =
              %{}
              |> maybe_put(:artwork_url, meta.image_url)
              |> maybe_put(:title, meta.name)
              |> maybe_put(:description, meta.description)
              |> maybe_put(:animation_url, meta.animation_url)
              |> Map.put(:metadata_status, :resolved)

            {:ok, _} = update_artwork(artwork, attrs)
            {:ok, Repo.reload(artwork)}

          {:error, reason} ->
            update_artwork(artwork, %{metadata_status: :failed})
            {:error, reason}
        end

      {:error, reason} ->
        update_artwork(artwork, %{metadata_status: :failed})
        {:error, reason}
    end
  end

  def resolve(%Artwork{source_type: :auction_listing, source_ref: ref} = artwork) when is_binary(ref) do
    case parse_auction_ref(ref) do
      {:ok, chain_id, _contract, _token_id, listing_id} ->
        with {:ok, listing_meta} <- fetch_auction_listing(chain_id, listing_id),
             {:ok, token_address, token_id} <- extract_token_from_listing(ref),
             {:ok, nft_meta} <- resolve_nft(chain_id, token_address, token_id) do
          attrs =
            %{}
            |> maybe_put(:artwork_url, nft_meta.image_url)
            |> maybe_put(:title, nft_meta.name)
            |> maybe_put(:description, nft_meta.description)
            |> maybe_put(:animation_url, nft_meta.animation_url)
            |> Map.put(:listing_meta, listing_meta)
            |> Map.put(:metadata_status, :resolved)

          {:ok, _} = update_artwork(artwork, attrs)
          {:ok, Repo.reload(artwork)}
        else
          {:error, reason} ->
            update_artwork(artwork, %{metadata_status: :failed})
            {:error, reason}
        end

      {:error, reason} ->
        update_artwork(artwork, %{metadata_status: :failed})
        {:error, reason}
    end
  end

  # ── URL metadata (OG tags) ──────────────────────────────────

  defp fetch_url_metadata(url) do
    case http_get(url) do
      {:ok, body} ->
        meta = parse_og_tags(body)
        {:ok, %{meta | image_url: meta.image_url || url}}

      {:error, _} = err ->
        err
    end
  end

  defp parse_og_tags(html) do
    title = extract_meta(html, "og:title") || extract_title_tag(html)
    description = extract_meta(html, "og:description")
    image_url = extract_meta(html, "og:image")
    artist = extract_meta(html, "og:article:author") || extract_meta(html, "og:site_name")
    aspect_ratio = parse_aspect_ratio(extract_meta(html, "og:image:width"), extract_meta(html, "og:image:height"))

    %{
      title: title,
      description: description,
      image_url: image_url,
      artist: artist,
      aspect_ratio: aspect_ratio
    }
  end

  defp extract_meta(html, property) do
    Regex.run(~r/<meta\s+(?:property|name)=["']#{Regex.escape(property)}["']\s+content=["']([^"']*)["']/i, html)
    |> case do
      [_, val] -> val
      _ -> nil
    end
  end

  defp extract_title_tag(html) do
    Regex.run(~r/<title>([^<]*)<\/title>/i, html)
    |> case do
      [_, val] -> String.trim(val)
      _ -> nil
    end
  end

  defp parse_aspect_ratio(nil, _), do: nil
  defp parse_aspect_ratio(_, nil), do: nil

  defp parse_aspect_ratio(w_str, h_str) do
    with {w, ""} <- Integer.parse(w_str),
         {h, ""} <- Integer.parse(h_str),
         true <- w > 0 and h > 0 do
      w / h
    else
      _ -> nil
    end
  end

  # ── NFT metadata (on-chain tokenURI + JSON) ─────────────────

  defp resolve_nft(chain_id, contract, token_id) do
    with {:ok, token_uri} <- fetch_token_uri(chain_id, contract, token_id),
         resolved_url = resolve_uri(token_uri),
         {:ok, meta} <- fetch_nft_metadata(resolved_url) do
      {:ok, meta}
    end
  end

  defp fetch_token_uri(chain_id, contract, token_id) do
    rpc_url = rpc_url_for_chain(chain_id)
    data = @token_uri_selector <> pad_left(to_hex(token_id), 64)

    case eth_call(rpc_url, contract, data) do
      {:ok, result} when is_binary(result) and result != "0x" ->
        {:ok, decode_abi_string(result)}

      {:ok, _} ->
        {:error, :no_token_uri}

      error ->
        error
    end
  end

  defp fetch_nft_metadata(url) do
    case http_get(url) do
      {:ok, body} ->
        case Jason.decode(body) do
          {:ok, json} when is_map(json) ->
            raw_image = json["image"] || json["imageUrl"] || json["image_url"]
            raw_animation = json["animation_url"] || json["animationUrl"]

            {:ok,
             %{
               name: json["name"],
               description: json["description"],
               image_url: if(is_binary(raw_image), do: resolve_uri(raw_image), else: nil),
               animation_url: if(is_binary(raw_animation), do: resolve_uri(raw_animation), else: nil),
               attributes: json["attributes"] || json["properties"]
             }}

          _ ->
            {:error, :invalid_metadata_json}
        end

      error ->
        error
    end
  end

  # ── Auction listing metadata ────────────────────────────────

  defp fetch_auction_listing(chain_id, listing_id) do
    rpc_url = rpc_url_for_chain(chain_id)
    marketplace_addr = marketplace_address(chain_id)

    if is_nil(marketplace_addr) do
      {:error, {:unsupported_chain, chain_id}}
    else
      data = @get_listing_selector <> pad_left(to_hex(listing_id), 64)

      case eth_call(rpc_url, marketplace_addr, data) do
        {:ok, raw_data} when is_binary(raw_data) and raw_data != "0x" ->
          seller = extract_address(raw_data, 64)
          listing_type = extract_uint8(raw_data, 256)
          start_time = extract_uint48(raw_data, 384)
          end_time = extract_uint48(raw_data, 416)
          bid_amount = decode_uint256_at(raw_data, 448)
          bidder = extract_address(raw_data, 480)
          erc20 = extract_address(raw_data, 288)
          total_sold = extract_uint24(raw_data, 128)

          # Fetch current price separately
          price_data = @get_current_price_selector <> pad_left(to_hex(listing_id), 64)
          current_price =
            case eth_call(rpc_url, marketplace_addr, price_data) do
              {:ok, price_hex} when is_binary(price_hex) and price_hex != "0x" ->
                decode_uint256(price_hex)

              _ ->
                nil
            end

          {:ok,
           %{
             listing_id: listing_id,
             seller: seller,
             listing_type: listing_type,
             finalized: false,
             start_time: start_time,
             end_time: end_time,
             current_price: current_price,
             bid_amount: bid_amount,
             bidder: bidder,
             erc20: erc20,
             total_sold: total_sold
           }}

        {:ok, _} ->
          {:error, :listing_not_found}

        error ->
          error
      end
    end
  end

  # Extract token contract and token_id from the auction source_ref.
  # source_ref format: "chain:contract:token_id:listing_id"
  defp extract_token_from_listing(ref) do
    case String.split(ref, ":") do
      [_chain, contract, token_id, _listing_id] ->
        {:ok, String.downcase(contract), token_id}

      _ ->
        {:error, :invalid_auction_ref}
    end
  end

  # ── RPC helpers ──────────────────────────────────────────────

  defp rpc_url_for_chain(chain_id) do
    case chain_id do
      1 -> Application.get_env(:such_gallery_elixir, :ethereum_rpc_url, "https://eth.llamarpc.com")
      8453 -> Application.get_env(:such_gallery_elixir, :base_rpc_url, "https://mainnet.base.org")
      _ -> Application.get_env(:such_gallery_elixir, :rpc_url)
    end
  end

  defp marketplace_address(chain_id) do
    case chain_id do
      8453 -> "0x1Cb0c1F72Ba7547fC99c4b5333d8aBA1eD6b31A9"
      1 -> "0x3CEE515879FFe4620a1F8aC9bf09B97e858815Ef"
      _ -> nil
    end
  end

  defp eth_call(rpc_url, contract, data) do
    payload =
      %{
        "jsonrpc" => "2.0",
        "method" => "eth_call",
        "params" => [%{"to" => contract, "data" => data}, "latest"],
        "id" => 1
      }
      |> Jason.encode!()

    headers = [{"Content-Type", "application/json"}]

    case :httpc.request(
           :post,
           {String.to_charlist(rpc_url), headers, ~c"application/json", payload},
           [{:timeout, @rpc_timeout}],
           []
         ) do
      {:ok, {{_, 200, _}, _, body}} ->
        case Jason.decode(to_string(body)) do
          {:ok, %{"result" => result}} -> {:ok, result}
          {:ok, %{"error" => %{"message" => msg}}} -> {:error, {:rpc_error, msg}}
          _ -> {:error, :invalid_rpc_response}
        end

      {:ok, {{_, code, _}, _, _}} ->
        {:error, {:http_error, code}}

      {:error, reason} ->
        {:error, {:rpc_error, reason}}
    end
  end

  # ── ABI decoding ─────────────────────────────────────────────

  defp decode_abi_string("0x" <> hex) do
    <<offset::binary-size(64), rest::binary>> = String.downcase(hex)

    with {byte_offset, ""} <- Integer.parse(offset, 16),
         char_offset = byte_offset * 2,
         true <- byte_size(rest) >= char_offset do
      <<_padding::binary-size(char_offset), len_hex::binary-size(64), data_hex::binary>> = rest

      with {byte_len, ""} <- Integer.parse(len_hex, 16),
           data_byte_len = byte_len * 2,
           true <- byte_size(data_hex) >= data_byte_len do
        data_hex
        |> binary_part(0, data_byte_len)
        |> Base.decode16(case: :lower)
        |> case do
          {:ok, bytes} -> to_string(bytes)
          _ -> nil
        end
      else
        _ -> nil
      end
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp decode_abi_string(_), do: nil

  defp decode_uint256("0x" <> hex) do
    hex |> String.downcase() |> String.trim_leading("0") |> String.to_integer(16)
  rescue
    _ -> 0
  end

  defp decode_uint256(_), do: 0

  defp decode_uint256_at("0x" <> data, offset) when byte_size(data) >= offset + 32 do
    segment = binary_part(data, offset, 32)

    case Base.decode16(segment, case: :lower) do
      {:ok, <<n::256>>} -> n
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp decode_uint256_at(_, _), do: 0

  defp extract_address("0x" <> data, offset) when byte_size(data) >= offset + 32 do
    segment = binary_part(data, offset, 32)

    case Base.decode16(segment, case: :lower) do
      {:ok, <<_::binary-size(12), addr::binary-size(20)>>} ->
        "0x" <> Base.encode16(addr, case: :lower)

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  defp extract_address(_, _), do: nil

  defp extract_uint8("0x" <> data, offset) when byte_size(data) >= offset + 32 do
    segment = binary_part(data, offset, 32)
    # uint8 is in the last byte of the 32-byte slot
    last_byte = binary_part(segment, 30, 2)

    case Base.decode16(last_byte, case: :lower) do
      {:ok, <<n>>} -> n
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp extract_uint8(_, _), do: 0

  defp extract_uint24("0x" <> data, offset) when byte_size(data) >= offset + 32 do
    segment = binary_part(data, offset, 32)
    last_3 = binary_part(segment, 26, 6)

    case Base.decode16(last_3, case: :lower) do
      {:ok, <<n::24>>} -> n
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp extract_uint24(_, _), do: 0

  defp extract_uint48("0x" <> data, offset) when byte_size(data) >= offset + 32 do
    segment = binary_part(data, offset, 32)
    last_6 = binary_part(segment, 20, 12)

    case Base.decode16(last_6, case: :lower) do
      {:ok, <<n::48>>} -> n
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp extract_uint48(_, _), do: 0

  # ── URI resolution (IPFS) ───────────────────────────────────

  @doc """
  Resolves IPFS URIs to HTTP gateway URLs.

  - `ipfs://CID` → `https://ipfs.io/ipfs/CID`
  - `ipfs/CID` → `https://ipfs.io/ipfs/CID`
  - anything else → returned as-is
  """
  def resolve_uri(uri) when is_binary(uri) do
    cond do
      String.starts_with?(uri, "ipfs://") ->
        @ipfs_gateway <> String.slice(uri, 7, String.length(uri))

      String.starts_with?(uri, "ipfs/") ->
        @ipfs_gateway <> String.slice(uri, 5, String.length(uri))

      true ->
        uri
    end
  end

  def resolve_uri(nil), do: nil

  # ── Parsing helpers ──────────────────────────────────────────

  defp parse_nft_ref(ref) do
    case String.split(ref, ":") do
      [chain, contract, token_id] ->
        with {chain_id, ""} <- Integer.parse(chain),
             true <- String.starts_with?(contract, "0x") do
          {:ok, chain_id, String.downcase(contract), token_id}
        else
          _ -> {:error, :invalid_nft_ref}
        end

      _ ->
        {:error, :invalid_nft_ref}
    end
  end

  defp parse_auction_ref(ref) do
    case String.split(ref, ":") do
      [chain, contract, token_id, listing_id] ->
        with {chain_id, ""} <- Integer.parse(chain),
             true <- String.starts_with?(contract, "0x") do
          {:ok, chain_id, String.downcase(contract), token_id, listing_id}
        else
          _ -> {:error, :invalid_auction_ref}
        end

      _ ->
        {:error, :invalid_auction_ref}
    end
  end

  # ── Hex helpers ──────────────────────────────────────────────

  defp to_hex(n) when is_integer(n), do: "0x" <> Integer.to_string(n, 16)
  defp to_hex(s) when is_binary(s), do: s

  defp pad_left(hex_str, target_length) do
    hex_str
    |> String.replace_prefix("0x", "")
    |> String.pad_leading(target_length, "0")
  end

  # ── HTTP helpers ────────────────────────────────────────────

  defp http_get(url) do
    headers = [
      {"User-Agent", "SuchGalleryElixir/1.0"},
      {"Accept", "*/*"}
    ]

    case :httpc.request(
           :get,
           {String.to_charlist(url), headers, [], []},
           [{:timeout, @http_timeout}],
           []
         ) do
      {:ok, {{_, 200, _}, _, body}} ->
        {:ok, to_string(body)}

      {:ok, {{_, code, _}, _, _}} ->
        {:error, {:http_error, code}}

      {:error, reason} ->
        {:error, {:http_error, reason}}
    end
  end

  # ── DB helpers ───────────────────────────────────────────────

  defp update_artwork(artwork, attrs) do
    artwork
    |> Artwork.metadata_changeset(attrs)
    |> Repo.update()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
