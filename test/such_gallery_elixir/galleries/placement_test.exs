defmodule SuchGalleryElixir.Galleries.PlacementTest do
  use SuchGalleryElixir.DataCase, async: true

  alias SuchGalleryElixir.Galleries
  alias SuchGalleryElixir.Galleries.{ArtworkPlacement, Gallery, PlacementResolver}
  alias SuchGalleryElixir.GalleriesFixtures

  describe "assign_artwork_to_slot/4" do
    test "assigns artwork to a predefined slot" do
      gallery = GalleriesFixtures.gallery_fixture()
      artwork = GalleriesFixtures.artwork_fixture()
      slot = GalleriesFixtures.slot_fixture(gallery)

      assert {:ok, %ArtworkPlacement{kind: :slot}} =
               Galleries.assign_artwork_to_slot(gallery, artwork, slot, 0)
    end

    test "rejects duplicate slot assignment" do
      gallery = GalleriesFixtures.gallery_fixture()
      slot = GalleriesFixtures.slot_fixture(gallery)

      assert {:ok, _} =
               Galleries.assign_artwork_to_slot(
                 gallery,
                 GalleriesFixtures.artwork_fixture(),
                 slot,
                 0
               )

      assert {:error, :slot_taken} =
               Galleries.assign_artwork_to_slot(
                 gallery,
                 GalleriesFixtures.artwork_fixture(),
                 slot,
                 1
               )
    end
  end

  describe "add_extra/3" do
    test "requires override coordinates" do
      gallery = GalleriesFixtures.gallery_fixture()
      artwork = GalleriesFixtures.artwork_fixture()

      assert {:error, changeset} =
               Galleries.add_extra(gallery, artwork, %{
                 display_order: 99,
                 override_wall: :back
               })

      assert %{override_u: ["can't be blank"]} = errors_on(changeset)
    end

    test "creates extra with overrides" do
      gallery = GalleriesFixtures.gallery_fixture()
      artwork = GalleriesFixtures.artwork_fixture()

      assert {:ok, %ArtworkPlacement{kind: :extra}} =
               Galleries.add_extra(gallery, artwork, %{
                 display_order: 50,
                 override_wall: :left,
                 override_u: 0.25,
                 override_v: 0.6,
                 override_rotation_y: 0.1,
                 override_scale: 1.2
               })
    end
  end

  describe "PlacementResolver" do
    test "resolves stable world coordinates for a slot" do
      gallery = GalleriesFixtures.gallery_fixture()
      artwork = GalleriesFixtures.artwork_fixture()
      slot = GalleriesFixtures.slot_fixture(gallery)

      {:ok, placement} = Galleries.assign_artwork_to_slot(gallery, artwork, slot, 0)
      placement = Repo.preload(placement, [:artwork, :layout_slot])

      resolved = PlacementResolver.resolve(placement, gallery)

      assert resolved.x == (slot.u - 0.5) * Gallery.width(gallery)
      assert resolved.y == slot.v * 3.0
      assert resolved.z == -Gallery.depth(gallery) / 2 + 0.01
      assert resolved.wall == :back
      assert resolved.artwork_url == artwork.artwork_url
    end
  end
end
