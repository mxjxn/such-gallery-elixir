# Square-room demo gallery (4 artworks, 1 per wall). Requires square_32 template.

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
          description: "Square gallery with 1 frame per wall (4 total)"
        },
        template.slug
      )

    gallery = Repo.preload(gallery, template: :layout_slots)

    # Pick the first slot on each wall (slot_index 0, 8, 16, 24)
    gallery.template.layout_slots
    |> Enum.filter(fn slot -> rem(slot.slot_index, 8) == 0 end)
    |> Enum.with_index()
    |> Enum.each(fn {slot, index} ->
      {:ok, artwork} =
        Galleries.create_artwork(%{
          artwork_url: "https://picsum.photos/seed/square#{index}/400/600",
          title: "Wall #{slot.wall} · #{index + 1}",
          artist: "Demo Artist"
        })

      Galleries.assign_artwork_to_slot(gallery, artwork, slot, index)
    end)

    :ok
  end
end
