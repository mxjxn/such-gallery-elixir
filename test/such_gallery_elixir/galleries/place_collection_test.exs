defmodule SuchGalleryElixir.Galleries.PlaceCollectionTest do
  use SuchGalleryElixir.DataCase

  alias SuchGalleryElixir.Galleries
  alias SuchGalleryElixir.GalleriesFixtures

  setup do
    # Create a template with 4 slots
    template =
      GalleriesFixtures.template_fixture(%{
        slug: "minimal_4",
        name: "Minimal (4 frames)",
        slot_count: 4
      })

    # Add 2 more slots (fixture creates 2 by default)
    SuchGalleryElixir.GalleriesFixtures.add_slots(template.id, 2, 4)

    {:ok, gallery} =
      Galleries.create_gallery(%{
        name: "Test Gallery",
        slug: "test-place-collection-#{System.unique_integer([:positive])}"
      }, "minimal_4")

    %{gallery: gallery, template: template}
  end

  describe "place_collection/2" do
    test "places artworks from URLs into empty slots", %{gallery: gallery} do
      urls = [
        "https://example.com/art1.png",
        "https://example.com/art2.png"
      ]

      assert {:ok, %{placed: placed, skipped: []}} = Galleries.place_collection(gallery, urls)
      assert length(placed) == 2

      [first, second] = placed
      assert first.artwork.artwork_url == "https://example.com/art1.png"
      assert first.artwork.source_type == :url
      assert first.artwork.metadata_status == :pending
      assert second.artwork.artwork_url == "https://example.com/art2.png"
    end

    test "deduplicates by source_ref", %{gallery: gallery} do
      inputs = [
        "https://example.com/duplicate.png",
        "https://example.com/duplicate.png",
        "https://example.com/unique.png"
      ]

      assert {:ok, %{placed: placed, skipped: skipped}} =
               Galleries.place_collection(gallery, inputs)

      assert length(placed) == 2
      assert length(skipped) == 0
    end

    test "skips invalid inputs", %{gallery: gallery} do
      inputs = [
        "https://example.com/valid.png",
        "not-a-url",
        "also invalid"
      ]

      assert {:ok, %{placed: placed}} = Galleries.place_collection(gallery, inputs)
      assert length(placed) == 1
    end

    test "truncates to available slots", %{gallery: gallery} do
      # 4 slots — try to place 6 artworks
      urls =
        for i <- 1..6 do
          "https://example.com/art#{i}.png"
        end

      assert {:ok, %{placed: placed}} = Galleries.place_collection(gallery, urls)
      assert length(placed) == 4
    end

    test "returns empty placed when gallery is full", %{gallery: gallery} do
      urls = for i <- 1..4, do: "https://example.com/fill#{i}.png"
      assert {:ok, %{placed: placed}} = Galleries.place_collection(gallery, urls)
      assert length(placed) == 4

      assert {:ok, %{placed: []}} =
               Galleries.place_collection(gallery, ["https://example.com/overflow.png"])
    end

    test "increments display_order correctly", %{gallery: gallery} do
      urls = [
        "https://example.com/a.png",
        "https://example.com/b.png",
        "https://example.com/c.png"
      ]

      assert {:ok, %{placed: _placed}} = Galleries.place_collection(gallery, urls)

      orders =
        SuchGalleryElixir.Galleries.ArtworkPlacement
        |> where([p], p.gallery_id == ^gallery.id)
        |> order_by([p], p.display_order)
        |> select([p], p.display_order)
        |> SuchGalleryElixir.Repo.all()

      assert orders == [1, 2, 3]
    end

    test "reuses existing artwork if source_ref matches", %{gallery: _gallery} do
      # Place first artwork
      {:ok, gallery} =
        Galleries.create_gallery(%{
          name: "Gallery First",
          slug: "reuse-test-1-#{System.unique_integer([:positive])}"
        }, "minimal_4")

      assert {:ok, %{placed: [first]}} =
               Galleries.place_collection(gallery, ["https://example.com/reuse.png"])

      artwork_id = first.artwork.id

      # New gallery with same template
      {:ok, gallery2} =
        Galleries.create_gallery(%{
          name: "Gallery Second",
          slug: "reuse-test-2-#{System.unique_integer([:positive])}"
        }, "minimal_4")

      assert {:ok, %{placed: [second]}} =
               Galleries.place_collection(gallery2, ["https://example.com/reuse.png"])

      assert second.artwork.id == artwork_id
    end
  end
end
