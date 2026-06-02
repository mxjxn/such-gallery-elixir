# Square-room demo gallery (32 slots, 8 per wall). Requires square_32 template.

alias SuchGalleryElixir.Galleries
alias SuchGalleryElixir.Repo

defmodule SuchGalleryElixir.Seeds.Square do
  @moduledoc false

  def run do
    case Galleries.get_gallery_by_slug("square") do
      %{} ->
        :ok

      nil ->
        seed_square()
    end
  end

  defp seed_square do
    template = Galleries.get_template_by_slug("square_32")

    {:ok, gallery} =
      Galleries.create_gallery(
        %{
          name: "Square Room",
          slug: "square",
          description: "Square gallery with 8 frames on each wall"
        },
        template.slug
      )

    gallery = Repo.preload(gallery, template: :layout_slots)

    for {slot, index} <- Enum.with_index(gallery.template.layout_slots) do
      {:ok, artwork} =
        Galleries.create_artwork(%{
          artwork_url: "https://picsum.photos/seed/square#{index}/400/600",
          title: "Wall #{slot.wall} · #{slot.slot_index + 1}",
          artist: "Demo Artist"
        })

      Galleries.assign_artwork_to_slot(gallery, artwork, slot, index)
    end

    :ok
  end
end
