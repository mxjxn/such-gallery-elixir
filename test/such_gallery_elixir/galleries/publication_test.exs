defmodule SuchGalleryElixir.Galleries.PublicationTest do
  use SuchGalleryElixir.DataCase, async: true

  alias SuchGalleryElixir.Galleries
  alias SuchGalleryElixir.AccountsFixtures

  import SuchGalleryElixir.GalleriesFixtures

  test "publishes immutable revisions and can remove the current public pointer" do
    owner = AccountsFixtures.user_fixture(%{display_name: "Curator"})
    gallery = gallery_fixture(%{owner_id: owner.id, name: "Signal Garden"})

    artwork =
      artwork_fixture(%{
        title: "Ragnarok",
        artist: "artiste.eth",
        chain_id: 1,
        contract_address: "0x1111111111111111111111111111111111111111",
        token_id: "5",
        canonical_media_uri: "ipfs://bafy-artwork"
      })

    assert {:ok, _placement} =
             Galleries.assign_artwork_to_slot(gallery, artwork, slot_fixture(gallery), 1)

    assert {:ok, first} = Galleries.publish_gallery(gallery)
    assert first.revision == 1
    assert first.manifest["gallery"]["title"] == gallery.name
    assert first.manifest["gallery"]["curator"]["walletAddress"] == owner.wallet_address

    [placement] = first.manifest["gallery"]["placements"]
    assert placement["artwork"]["chainId"] == 1
    assert placement["artwork"]["tokenId"] == "5"

    assert {:ok, second} = Galleries.publish_gallery(gallery)
    assert second.revision == 2
    assert Galleries.get_published_exhibition_by_slug(gallery.slug).revision == 2

    assert Galleries.get_publication_by_slug_and_revision(gallery.slug, 1).manifest ==
             first.manifest

    assert {:ok, _gallery} = Galleries.unpublish_gallery(gallery)
    assert Galleries.get_published_exhibition_by_slug(gallery.slug) == nil
    assert Galleries.get_publication_by_slug_and_revision(gallery.slug, 1)
  end
end
