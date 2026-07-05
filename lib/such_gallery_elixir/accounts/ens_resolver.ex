defmodule SuchGalleryElixir.Accounts.EnsResolver do
  @moduledoc """
  Resolves Ethereum addresses to ENS names via Alchemy JSON-RPC.

  Calls the ENS ReverseRegistrar contract's `name(address)` function,
  which takes a raw address (no namehash needed) and returns the
  forward ENS name. The contract handles namehash computation internally.

  Falls back silently — if resolution fails for any reason, the caller
  uses the truncated address instead.
  """

  # ENS ReverseRegistrar (mainnet) — ENSIP-19
  # function name(address addr) returns (string)
  @reverse_registrar "0x084b1c3C81545d370f3634392De611cAc41B2794"
  @name_selector "0x02571be3"

  @http_timeout 10_000

  @doc """
  Resolves an ENS name for the given Ethereum address.

  Returns `{:ok, ens_name}` (e.g. `{:ok, "vitalik.eth"}`) or
  `{:error, :not_found}` if no reverse ENS record is set.

  Silently catches all failures as `{:error, :not_found}` — callers
  should fall back to truncated address display on error.
  """
  @spec resolve_address(String.t()) :: {:ok, String.t()} | {:error, :not_found}
  def resolve_address(address) when is_binary(address) do
    calldata = @name_selector <> pad_address(address)

    case rpc_call("eth_call", [%{to: @reverse_registrar, data: calldata}, "latest"]) do
      {:ok, result} when result in [nil, "0x", "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000000"] ->
        {:error, :not_found}

      {:ok, result} ->
        case decode_abi_string(result) do
          "" -> {:error, :not_found}
          name -> {:ok, name}
        end

      {:error, _} ->
        {:error, :not_found}
    end
  rescue
    _ -> {:error, :not_found}
  end

  # ── ABI encoding / decoding ──────────────────────────────────

  defp pad_address(address) do
    address
    |> String.replace_prefix("0x", "")
    |> String.downcase()
    |> String.pad_leading(40, "0")
    |> then(&(String.duplicate("0", 24) <> &1))
  end

  defp decode_abi_string("0x" <> hex) when byte_size(hex) >= 128 do
    # ABI dynamic string: [offset:32][length:32][data:N]
    # offset is typically 0x20 (32 bytes) — string length follows immediately
    length =
      hex
      |> String.slice(64, 64)
      |> String.to_integer(16)

    if length == 0 or length > 256 do
      ""
    else
      hex
      |> String.slice(128, length * 2)
      |> decode_hex_to_string()
    end
  end

  defp decode_abi_string(_), do: ""

  defp decode_hex_to_string(hex) do
    for <<byte::binary-2 <- hex>>, byte != "", into: "" do
      <<String.to_integer(byte, 16)>>
    end
  end

  # ── JSON-RPC to Alchemy mainnet ───────────────────────────────

  defp rpc_call(method, params) do
    api_key = Application.get_env(:such_gallery_elixir, :alchemy_api_key) || ""

    payload =
      %{
        "jsonrpc" => "2.0",
        "method" => method,
        "id" => 1,
        "params" => params
      }
      |> Jason.encode!()

    url = "https://eth-mainnet.g.alchemy.com/v2/#{api_key}"
    headers = [{"Content-Type", "application/json"}]

    case :httpc.request(
           :post,
           {String.to_charlist(url), headers, ~c"application/json", payload},
           [{:timeout, @http_timeout}],
           []
         ) do
      {:ok, {{_, 200, _}, _, body}} ->
        case Jason.decode(to_string(body)) do
          {:ok, %{"result" => result}} -> {:ok, result}
          _ -> {:error, :invalid_response}
        end

      _ ->
        {:error, :rpc_failed}
    end
  end
end
