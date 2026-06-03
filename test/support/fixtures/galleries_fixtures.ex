defmodule SuchGalleryElixir.GalleriesFixtures do
  @moduledoc false

  import Ecto.Query

  alias SuchGalleryElixir.Galleries
  alias SuchGalleryElixir.Galleries.{Gallery, GalleryTemplate, LayoutSlot}
  alias SuchGalleryElixir.Repo

  def unique_slug, do: "gallery-#{System.unique_integer([:positive])}"

  def template_fixture(attrs \\ %{}) do
    slug = Map.get(attrs, :slug, "test-#{System.unique_integer([:positive])}")

    {:ok, template} =
      %GalleryTemplate{}
      |> GalleryTemplate.changeset(
        Map.merge(
          %{
            slug: slug,
            name: "Test Template",
            slot_count: 2,
            layout: :rectangular,
            width: 10.0,
            depth: 8.0
          },
          attrs
        )
      )
      |> Repo.insert()

    for index <- 0..1 do
      %LayoutSlot{}
      |> LayoutSlot.changeset(%{
        template_id: template.id,
        slot_index: index,
        wall: :back,
        u: (index + 1) / 3,
        v: 0.5
      })
      |> Repo.insert!()
    end

    Repo.preload(template, :layout_slots)
  end

  def add_slots(template_id, start_index, end_index) do
    for index <- start_index..(end_index - 1) do
      %SuchGalleryElixir.Galleries.LayoutSlot{}
      |> SuchGalleryElixir.Galleries.LayoutSlot.changeset(%{
        template_id: template_id,
        slot_index: index,
        wall: :back,
        u: (index + 1) / (end_index + 1),
        v: 0.5
      })
      |> SuchGalleryElixir.Repo.insert!()
    end
  end

  def gallery_fixture(attrs \\ %{}) do
    template =
      case Map.get(attrs, :template) do
        %GalleryTemplate{} = t -> t
        _ -> template_fixture()
      end

    attrs =
      attrs
      |> Map.drop([:template])
      |> Map.merge(%{
        name: "Test Gallery",
        slug: unique_slug(),
        template_id: template.id
      })

    {:ok, gallery} =
      %Gallery{}
      |> Gallery.changeset(attrs)
      |> Repo.insert()

    Map.put(gallery, :template, template)
  end

  def artwork_fixture(attrs \\ %{}) do
    {:ok, artwork} =
      attrs
      |> Map.merge(%{artwork_url: "https://example.com/#{System.unique_integer()}.png"})
      |> then(&Galleries.create_artwork/1)

    artwork
  end

  def slot_fixture(%Gallery{template: %{layout_slots: [slot | _]}}), do: slot

  def slot_fixture(%Gallery{template_id: template_id}) do
    LayoutSlot
    |> where(template_id: ^template_id)
    |> order_by([s], asc: s.slot_index)
    |> limit(1)
    |> Repo.one!()
  end
end
