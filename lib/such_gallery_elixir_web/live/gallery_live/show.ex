defmodule SuchGalleryElixirWeb.GalleryLive.Show do
  @moduledoc """
  Magazine-mode gallery: artwork grid, visitor list, and real-time chat.

  Connects to `room:{gallery_id}` via the GalleryRoom JS hook for presence;
  chat is mirrored through PubSub so multiple LiveView tabs stay in sync.
  """

  use SuchGalleryElixirWeb, :live_view

  alias SuchGalleryElixir.Galleries

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Galleries.get_gallery_by_slug(slug) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Gallery not found")
         |> push_navigate(to: ~p"/")}

      gallery ->
        placements =
          gallery
          |> Galleries.list_placements()
          |> then(&Galleries.resolve_placement_transforms(&1, gallery))

        guest_name = "Guest-#{:rand.uniform(9999)}"

        chat_messages = Galleries.list_recent_chat_messages(gallery.id)

        socket =
          socket
          |> assign(:page_title, gallery.name)
          |> assign(:gallery, gallery)
          |> assign(:placements, placements)
          |> assign(:guest_name, guest_name)
          |> assign(:guest_color, random_color())
          |> assign(:chat_messages, chat_messages)
          |> assign(:presences, [])

        if connected?(socket) do
          Phoenix.PubSub.subscribe(SuchGalleryElixir.PubSub, pubsub_topic(gallery.id))
        end

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("send_chat", params, socket) do
    case chat_text(params) do
      "" ->
        {:noreply, socket}

      text ->
        case Galleries.create_chat_message(
               socket.assigns.gallery.id,
               socket.assigns.guest_name,
               text
             ) do
          {:ok, message} ->
            Phoenix.PubSub.broadcast_from(
              SuchGalleryElixir.PubSub,
              self(),
              pubsub_topic(socket.assigns.gallery.id),
              {:chat, message}
            )

            {:noreply, append_chat(socket, message)}

          {:error, _changeset} ->
            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("presence_update", %{"presences" => presences}, socket) do
    {:noreply, assign(socket, :presences, normalize_presences(presences))}
  end

  @impl true
  def handle_info({:presence_update, presences}, socket) do
    {:noreply, assign(socket, :presences, presences)}
  end

  @impl true
  def handle_info({:chat, message}, socket) do
    {:noreply, append_chat(socket, message)}
  end

  defp pubsub_topic(gallery_id), do: "gallery:#{gallery_id}"

  defp chat_text(%{"text" => text}) when is_binary(text), do: String.trim(text)
  defp chat_text(%{"chat" => %{"text" => text}}) when is_binary(text), do: String.trim(text)
  defp chat_text(_), do: ""

  defp append_chat(socket, message) do
    assign(socket, :chat_messages, socket.assigns.chat_messages ++ [normalize_chat(message)])
  end

  defp normalize_chat(message) do
    %{
      name: message[:name] || message["name"] || "Guest",
      text: message[:text] || message["text"] || "",
      at: message[:at] || message["at"]
    }
  end

  defp normalize_presences(presences) when is_list(presences) do
    presences
    |> List.flatten()
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn p ->
      %{
        "id" => to_string(p["id"] || p[:id] || ""),
        "name" => p["name"] || p[:name] || "Guest",
        "color" => p["color"] || p[:color] || "#ff5500",
        "x" => p["x"] || p[:x] || 0,
        "z" => p["z"] || p[:z] || 0
      }
    end)
  end

  defp normalize_presences(_), do: []

  defp random_color do
    hue = :rand.uniform(360)
    "hsl(#{hue}, 70%, 55%)"
  end
end
