defmodule SuchGalleryElixirWeb.GalleryLive.Curate do
  @moduledoc """
  2D curation page for assigning NFTs to gallery frame slots.

  Shows a grid of frame slots (from template), each with current artwork
  or empty state. Clicking a slot opens an assignment modal with three
  input methods: paste link, browse wallet, direct lookup.

  All lookups happen server-side in handle_event callbacks. The LV process
  blocks briefly during API calls, which is acceptable for a curator tool.
  """

  use SuchGalleryElixirWeb, :live_view

  alias SuchGalleryElixir.Galleries
  alias SuchGalleryElixir.Galleries.{Artwork, ArtworkPlacement, Lookup}
  alias SuchGalleryElixir.Repo
  import Ecto.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:gallery, nil)
     |> assign(:slug, nil)
     |> assign(:active_slot, nil)
     |> assign(:active_tab, "paste")
     |> assign(:paste_input, "")
     |> assign(:resolve_result, nil)
     |> assign(:resolve_error, nil)
     |> assign(:wallet_address, "")
     |> assign(:wallet_chain, "8453")
     |> assign(:wallet_nfts, [])
     |> assign(:wallet_page_key, nil)
     |> assign(:wallet_loading, false)
     |> assign(:wallet_total, 0)
     |> assign(:lookup_contract, "")
     |> assign(:lookup_chain, "8453")
     |> assign(:lookup_token_id, "")
     |> assign(:slots, [])}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _url, socket) do
    gallery = Galleries.get_gallery_by_slug(slug)

    if gallery do
      {:noreply,
       socket
       |> assign(:gallery, gallery)
       |> assign(:slug, slug)
       |> build_slot_grid()}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Gallery not found")
       |> push_navigate(to: ~p"/")}
    end
  end

  # ── Slot selection ──────────────────────────────────────────

  @impl true
  def handle_event("select_slot", %{"slot_id" => slot_id}, socket) do
    {:noreply,
     socket
     |> assign(:active_slot, String.to_integer(slot_id))
     |> assign(:resolve_result, nil)
     |> assign(:resolve_error, nil)}
  end

  @impl true
  def handle_event("close_slot", _params, socket) do
    {:noreply,
     socket
     |> assign(:active_slot, nil)
     |> assign(:resolve_result, nil)
     |> assign(:resolve_error, nil)
     |> assign(:wallet_nfts, [])}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # ── Tab 1: Paste + Resolve ──────────────────────────────────

  @impl true
  def handle_event("resolve", %{"input" => input}, socket) do
    input = String.trim(input)

    cond do
      input == "" ->
        {:noreply, assign(socket, resolve_error: "Enter a URL or NFT reference")}

      true ->
        case Lookup.resolve(input) do
          {:ok, data} ->
            {:noreply,
             socket
             |> assign(:resolve_result, data_to_map(data))
             |> assign(:resolve_error, nil)}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:resolve_error, error_message(reason))
             |> assign(:resolve_result, nil)}
        end
    end
  end

  # ── Tab 2: Browse Wallet ────────────────────────────────────

  @impl true
  def handle_event("browse_wallet", %{"address" => address, "chain" => chain}, socket) do
    address = String.trim(address)
    chain_id = if is_binary(chain), do: String.to_integer(chain), else: chain

    cond do
      address == "" ->
        {:noreply, assign(socket, resolve_error: "Enter a wallet address")}

      not valid_address?(address) ->
        {:noreply, assign(socket, resolve_error: "Invalid wallet address")}

      true ->
        case Lookup.browse_wallet(address, chain_id, nil) do
          {:ok, data} ->
            nfts =
              Enum.map(data.nfts, fn nft ->
                nft
                |> data_to_map()
                |> Map.put("source_ref", "nft:#{nft.chain_id}:#{nft.contract}:#{nft.token_id}")
              end)

            {:noreply,
             socket
             |> assign(:wallet_nfts, nfts)
             |> assign(:wallet_page_key, data.page_key)
             |> assign(:wallet_total, data.total)
             |> assign(:wallet_loading, false)
             |> assign(:wallet_address, address)
             |> assign(:wallet_chain, chain)}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:wallet_loading, false)
             |> assign(:resolve_error, error_message(reason))}
        end
    end
  end

  @impl true
  def handle_event("browse_more", _params, socket) do
    address = socket.assigns.wallet_address
    chain_id = String.to_integer(socket.assigns.wallet_chain)
    page_key = socket.assigns.wallet_page_key

    case Lookup.browse_wallet(address, chain_id, page_key) do
      {:ok, data} ->
        new_nfts =
          Enum.map(data.nfts, fn nft ->
            nft
            |> data_to_map()
            |> Map.put("source_ref", "nft:#{nft.chain_id}:#{nft.contract}:#{nft.token_id}")
          end)
        {:noreply,
         socket
         |> assign(:wallet_nfts, socket.assigns.wallet_nfts ++ new_nfts)
         |> assign(:wallet_page_key, data.page_key)
         |> assign(:wallet_loading, false)}

      {:error, _} ->
        {:noreply, assign(socket, :wallet_loading, false)}
    end
  end

  # ── Tab 3: Direct Lookup ───────────────────────────────────

  @impl true
  def handle_event("direct_lookup", %{"contract" => contract, "chain" => chain, "token_id" => token_id}, socket) do
    contract = String.trim(contract) |> String.downcase()
    chain = String.trim(chain)
    token_id = String.trim(token_id)

    cond do
      contract == "" or token_id == "" ->
        {:noreply, assign(socket, resolve_error: "Contract and token ID required")}

      true ->
        case Lookup.direct_lookup(contract, chain, token_id) do
          {:ok, data} ->
            {:noreply,
             socket
             |> assign(:resolve_result, data_to_map(data))
             |> assign(:resolve_error, nil)}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:resolve_error, error_message(reason))
             |> assign(:resolve_result, nil)}
        end
    end
  end

  # ── Assignment ──────────────────────────────────────────────

  @impl true
  def handle_event("assign_artwork", artwork_data, socket) do
    gallery = socket.assigns.gallery
    slot_id = String.to_integer(artwork_data["slot_id"])
    source_ref = artwork_data["source_ref"]
    source_type = String.to_atom(artwork_data["source_type"])
    image_url = artwork_data["image_url"] || ""
    title = artwork_data["title"] || ""
    collection = artwork_data["collection"] || ""

    # Find or create artwork
    existing = Repo.get_by(Artwork, source_ref: source_ref)

    artwork =
      case existing do
        nil ->
          attrs =
            %{
              artwork_url: image_url,
              source_type: source_type,
              source_ref: source_ref,
              external_id: source_ref,
              title: title,
              metadata_status: :resolved
            }
            |> maybe_put_artist(collection)

          {:ok, art} =
            %Artwork{}
            |> Artwork.changeset(attrs)
            |> Repo.insert()

          art

        art ->
          art
      end

    # Replace existing placement for this slot
    Repo.delete_all(
      from(p in ArtworkPlacement,
        where: p.gallery_id == ^gallery.id and p.layout_slot_id == ^slot_id
      )
    )

    {:ok, _} =
      %ArtworkPlacement{}
      |> ArtworkPlacement.changeset(%{
        kind: :slot,
        gallery_id: gallery.id,
        artwork_id: artwork.id,
        layout_slot_id: slot_id,
        display_order: slot_id
      })
      |> Repo.insert()

    # Reload
    gallery = Galleries.get_gallery_by_slug(socket.assigns.slug)

    {:noreply,
     socket
     |> assign(:gallery, gallery)
     |> assign(:active_slot, nil)
     |> assign(:resolve_result, nil)
     |> assign(:resolve_error, nil)
     |> build_slot_grid()
     |> put_flash(:info, "Artwork assigned")}
  end

  @impl true
  def handle_event("clear_slot", %{"slot_id" => slot_id}, socket) do
    gallery = socket.assigns.gallery
    slot_id_int = String.to_integer(slot_id)

    Repo.delete_all(
      from(p in ArtworkPlacement,
        where: p.gallery_id == ^gallery.id and p.layout_slot_id == ^slot_id_int
      )
    )

    gallery = Galleries.get_gallery_by_slug(socket.assigns.slug)

    {:noreply,
     socket
     |> assign(:gallery, gallery)
     |> assign(:active_slot, nil)
     |> build_slot_grid()
     |> put_flash(:info, "Slot cleared")}
  end

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  # ── Slot grid ────────────────────────────────────────────────

  defp build_slot_grid(socket) do
    gallery = socket.assigns.gallery
    template = gallery.template
    placements = gallery.artwork_placements || []

    slots =
      if template && template.layout_slots do
        template.layout_slots
        |> Enum.sort_by(& &1.slot_index)
        |> Enum.map(fn slot ->
          placement =
            Enum.find(placements, fn p ->
              p.layout_slot_id == slot.id
            end)

          %{
            id: slot.id,
            index: slot.slot_index,
            wall: slot.wall || "",
            artwork: if(placement, do: placement.artwork, else: nil)
          }
        end)
      else
        []
      end

    assign(socket, :slots, slots)
  end

  # ── Helpers ─────────────────────────────────────────────────

  defp maybe_put_artist(attrs, ""), do: attrs
  defp maybe_put_artist(attrs, collection), do: Map.put(attrs, :artist, collection)

  defp valid_address?(addr) do
    String.match?(addr, ~r/^0x[a-fA-F0-9]{40}$/)
  end

  defp error_message(:listing_not_found), do: "Listing not found on cryptoart.social"
  defp error_message(:invalid_input), do: "Invalid input format"
  defp error_message(:not_a_cryptoart_url), do: "Not a recognized cryptoart.social URL"
  defp error_message(:invalid_address), do: "Invalid Ethereum address"
  defp error_message(:invalid_params), do: "Invalid parameters"
  defp error_message({:http_error, code}), do: "API request failed (HTTP #{code})"
  defp error_message({:graphql_errors, _}), do: "Subgraph query failed"
  defp error_message({:alchemy_error, err}), do: "Alchemy API error: #{inspect(err)}"
  defp error_message(reason), do: inspect(reason)

  defp data_to_map(data) when is_map(data) do
    # Convert atom keys to string keys for JS interop in HEEx templates
    for {k, v} <- data, into: %{}, do: {to_string(k), v}
  end
  defp data_to_map(other), do: other

  @doc "Slot label for display"
  def slot_label(%{index: idx}), do: "Slot #{idx + 1}"

  @doc "Slot label for a specific slot ID"
  def slot_label_for(slots, slot_id) do
    case Enum.find(slots, &(&1.id == slot_id)) do
      nil -> "Unknown Slot"
      slot -> "Slot #{slot.index + 1}"
    end
  end

  @doc "Check if a slot has artwork"
  def slot_has_artwork?(slots, slot_id) do
    Enum.any?(slots, &(&1.id == slot_id && &1.artwork != nil))
  end

  @doc "Border CSS class for slot"
  def slot_border_class(%{artwork: nil}), do: "border-zinc-800 bg-zinc-900 hover:border-zinc-600 hover:bg-zinc-800"
  def slot_border_class(_), do: "border-zinc-700 bg-zinc-900 hover:border-zinc-500"

  @doc "Truncates Ethereum address"
  def short_address(nil), do: ""
  def short_address(""), do: ""
  def short_address(addr) when byte_size(addr) > 12,
    do: "#{String.slice(addr, 0, 6)}…#{String.slice(addr, -4, 4)}"
  def short_address(addr), do: addr

  @doc "CSS class for active tab"
  def tab_class(active, tab) when active == tab,
    do: "border-b-2 border-white text-white"
  def tab_class(_, _),
    do: "text-zinc-400 hover:text-zinc-200"

  attr :result, :map, required: true
  attr :slot_id, :integer, required: true
  attr :source_type, :string, default: "url"

  def resolve_preview(assigns) do
    source_ref = assigns.result["source_ref"] || assigns.result["contract"] || assigns.result["image_url"] || ""
    contract = assigns.result["contract"] || ""
    token_id = assigns.result["token_id"] || ""
    chain_id = assigns.result["chain_id"] || ""

    nft_source_ref =
      if contract != "" and token_id != "" do
        "nft:#{chain_id}:#{contract}:#{token_id}"
      else
        source_ref
      end

    assigns =
      assigns
      |> assign(:source_ref, source_ref)
      |> assign(:nft_source_ref, nft_source_ref)

    ~H"""
    <div class="flex gap-4">
      <img src={@result["image_url"]} alt="" class="h-24 w-24 rounded-lg object-cover bg-zinc-700" />
      <div class="flex-1 min-w-0">
        <p class="font-medium truncate"><%= @result["title"] || "Untitled" %></p>
        <p class="text-sm text-zinc-400 truncate"><%= @result["collection"] || "" %></p>
        <p class="mt-1 text-xs font-mono text-zinc-500"><%= short_address(@result["contract"]) %></p>
      </div>
    </div>
    <button type="button"
      class="mt-3 w-full rounded-lg bg-white px-4 py-2 text-sm font-medium text-zinc-900 hover:bg-zinc-200"
      phx-click="assign_artwork"
      phx-value-slot_id={@slot_id}
      phx-value-source_type={@source_type}
      phx-value-source_ref={@nft_source_ref}
      phx-value-title={@result["title"] || ""}
      phx-value-image_url={@result["image_url"] || ""}
      phx-value-contract={@result["contract"] || ""}
      phx-value-token_id={@result["token_id"] || ""}
      phx-value-chain_id={to_string(@result["chain_id"] || "")}
      phx-value-collection={@result["collection"] || ""}
    >
      Assign to Slot
    </button>
    """
  end
end
