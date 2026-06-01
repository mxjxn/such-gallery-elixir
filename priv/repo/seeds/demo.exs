# Demo gallery with slot placements. Requires templates from seeds/templates.exs.

alias SuchGalleryElixir.Galleries
alias SuchGalleryElixir.Repo

defmodule SuchGalleryElixir.Seeds.Demo do
  @moduledoc false

  def run do
    case Galleries.get_gallery_by_slug("demo") do
      %{} ->
        :ok

      nil ->
        seed_demo()
    end
  end

  defp seed_demo do
    template = Galleries.get_template_by_slug("minimal_4")

    {:ok, gallery} =
      Galleries.create_gallery(
        %{
          name: "Demo Gallery",
          slug: "demo",
          description: "Sample gallery for local development"
        },
        template.slug
      )

    gallery = Repo.preload(gallery, template: :layout_slots)

    slots = Enum.take(gallery.template.layout_slots, 3)

    for {slot, index} <- Enum.with_index(slots) do
      {:ok, artwork} =
        Galleries.create_artwork(%{
          artwork_url: "https://picsum.photos/seed/suchgallery#{index}/400/600",
          title: "Piece #{index + 1}",
          artist: "Demo Artist"
        })

      Galleries.assign_artwork_to_slot(gallery, artwork, slot, index)
    end

    :ok
  end
end
