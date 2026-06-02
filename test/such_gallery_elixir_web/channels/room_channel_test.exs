defmodule SuchGalleryElixirWeb.RoomChannelTest do
  use SuchGalleryElixirWeb.ChannelCase, async: false

  import Phoenix.ChannelTest

  alias SuchGalleryElixir.GalleriesFixtures
  alias SuchGalleryElixirWeb.Presence

  setup do
    gallery = GalleriesFixtures.gallery_fixture()
    {:ok, gallery: gallery}
  end

  defp join_room(gallery_id, params \\ %{}) do
    SuchGalleryElixirWeb.UserSocket
    |> socket("user", %{})
    |> subscribe_and_join("room:#{gallery_id}", params)
  end

  describe "join/3" do
    test "pushes gallery and presence state after join", %{gallery: gallery} do
      {:ok, _reply, socket} = join_room(gallery.id, %{"name" => "Ada", "color" => "#3366cc"})

      assert_push "gallery_state", state
      assert state.id == gallery.id
      assert is_list(state.placements)

      assert_push "presence_state", presences
      assert Map.has_key?(presences, socket.id)
    end

    test "rejects unknown gallery" do
      assert {:error, %{reason: "not_found"}} = join_room(999_999, %{})
    end
  end

  describe "move/3" do
    test "updates presence position", %{gallery: gallery} do
      {:ok, _, socket} = join_room(gallery.id, %{"name" => "Mover"})

      ref = push(socket, "move", %{"x" => 1.5, "z" => -2.0})
      assert_reply ref, :ok, %{}

      %{metas: [%{x: 1.5, z: -2.0}]} = Presence.get_by_key(socket.topic, socket.id)
    end
  end

  describe "chat:new/3" do
    test "broadcasts chat to topic and pubsub", %{gallery: gallery} do
      Phoenix.PubSub.subscribe(SuchGalleryElixir.PubSub, "gallery:#{gallery.id}")

      {:ok, _, socket} = join_room(gallery.id, %{"name" => "Chatter"})

      ref = push(socket, "chat:new", %{"text" => "hello gallery"})
      assert_reply ref, :ok, %{}

      assert_broadcast "chat:new", %{name: "Chatter", text: "hello gallery", at: at}
      assert is_binary(at)

      assert_receive {:chat, %{name: "Chatter", text: "hello gallery"}}
    end
  end
end
