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

        socket =
          socket
          |> assign(:page_title, gallery.name)
          |> assign(:gallery, gallery)
          |> assign(:placements, placements)
          |> assign(:guest_name, guest_name)
          |> assign(:guest_color, random_color())
          |> assign(:chat_messages, [])
          |> assign(:presences, [])

        if connected?(socket) do
          Phoenix.PubSub.subscribe(SuchGalleryElixir.PubSub, pubsub_topic(gallery.id))
        end

        {:ok, socket}
    end
  end

  @impl true
  def handle_event("send_chat", %{"text" => text}, socket) do
    text = String.trim(text)

    if text == "" do
      {:noreply, socket}
    else
      {:noreply, push_event(socket, "chat_send", %{text: text})}
    end
  end

  @impl true
  def handle_event("presence_update", %{"presences" => presences}, socket) do
    {:noreply, assign(socket, :presences, presences)}
  end

  @impl true
  def handle_info({:chat, message}, socket) do
    {:noreply, assign(socket, :chat_messages, socket.assigns.chat_messages ++ [message])}
  end

  defp pubsub_topic(gallery_id), do: "gallery:#{gallery_id}"

  defp random_color do
    hue = :rand.uniform(360)
    "hsl(#{hue}, 70%, 55%)"
  end
end
