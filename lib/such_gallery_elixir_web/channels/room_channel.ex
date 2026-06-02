defmodule SuchGalleryElixirWeb.RoomChannel do
  @moduledoc """
  Real-time topic for a single gallery: avatars, chat, and initial gallery payload.

  Topic: `room:{gallery_id}` where `gallery_id` is the database id.
  """

  use SuchGalleryElixirWeb, :channel

  alias SuchGalleryElixir.Galleries
  alias SuchGalleryElixir.Galleries.Gallery
  alias SuchGalleryElixirWeb.Presence

  @impl true
  def join("room:" <> gallery_id_str, params, socket) do
    with {gallery_id, ""} <- Integer.parse(gallery_id_str),
         %Gallery{} = gallery <- Galleries.get_gallery_by_id(gallery_id) do
      socket =
        socket
        |> assign(:gallery_id, gallery_id)
        |> assign(:gallery, gallery)

      {:ok, _} =
        Presence.track(socket, socket.id, presence_meta(socket, params))

      send(self(), :after_join)
      {:ok, %{id: socket.id}, socket}
    else
      _ -> {:error, %{reason: "not_found"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    push(socket, "gallery_state", Galleries.gallery_state(socket.assigns.gallery))
    push(socket, "presence_state", Presence.list(socket))
    broadcast_presence(socket)

    {:noreply, socket}
  end

  @impl true
  def terminate(_reason, socket) do
    broadcast_presence(socket)
    :ok
  end

  @impl true
  def handle_in("move", %{"x" => x, "z" => z}, socket) do
    meta =
      socket
      |> presence_meta_for_socket()
      |> Map.merge(%{x: parse_float(x), z: parse_float(z)})

    {:ok, _} = Presence.update(socket, socket.id, meta)
    {:reply, {:ok, %{}}, socket}
  end

  @impl true
  def handle_in("chat:new", %{"text" => text}, socket) do
    text = String.trim(text)

    if text == "" do
      {:reply, {:ok, %{}}, socket}
    else
      meta = presence_meta_for_socket(socket)

      case Galleries.create_chat_message(socket.assigns.gallery_id, meta.name, text) do
        {:ok, message} ->
          broadcast!(socket, "chat:new", message)

          Phoenix.PubSub.broadcast(
            SuchGalleryElixir.PubSub,
            pubsub_topic(socket.assigns.gallery_id),
            {:chat, message}
          )

          {:reply, {:ok, %{}}, socket}

        {:error, _} ->
          {:reply, {:error, %{reason: "invalid_message"}}, socket}
      end
    end
  end

  defp presence_meta(socket, params) do
    %{
      id: socket.id,
      name: param_or_default(params, "name", "Guest"),
      color: param_or_default(params, "color", "#ff5500"),
      x: 0.0,
      z: 0.0
    }
  end

  defp presence_meta_for_socket(socket) do
    case Presence.get_by_key(socket.topic, socket.id) do
      %{metas: [meta | _]} -> meta
      _ -> %{id: socket.id, name: "Guest", color: "#ff5500", x: 0.0, z: 0.0}
    end
  end

  defp param_or_default(params, key, default) do
    case params[key] do
      value when is_binary(value) and value != "" -> value
      _ -> default
    end
  end

  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value * 1.0

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end

  defp parse_float(_), do: 0.0

  defp pubsub_topic(gallery_id), do: "gallery:#{gallery_id}"

  defp broadcast_presence(socket) do
    Phoenix.PubSub.broadcast(
      SuchGalleryElixir.PubSub,
      pubsub_topic(socket.assigns.gallery_id),
      {:presence_update, presence_list(socket)}
    )
  end

  defp presence_list(socket) do
    socket
    |> Presence.list()
    |> Enum.flat_map(fn {key, %{metas: metas}} ->
      Enum.map(metas, fn meta ->
        %{
          "id" => to_string(key),
          "name" => meta[:name] || meta["name"] || "Guest",
          "color" => meta[:color] || meta["color"] || "#ff5500",
          "x" => meta[:x] || meta["x"] || 0.0,
          "z" => meta[:z] || meta["z"] || 0.0
        }
      end)
    end)
  end
end
