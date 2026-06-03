defmodule SuchGalleryElixir.Galleries.ArtworkResolverTest do
  use SuchGalleryElixir.DataCase, async: true

  alias SuchGalleryElixir.Galleries.ArtworkResolver

  describe "resolve_uri/1" do
    test "converts ipfs:// URI to gateway URL" do
      assert "https://ipfs.io/ipfs/QmTest123" ==
               ArtworkResolver.resolve_uri("ipfs://QmTest123")
    end

    test "handles ipfs/ prefix (no colon)" do
      assert "https://ipfs.io/ipfs/QmTest456" ==
               ArtworkResolver.resolve_uri("ipfs/QmTest456")
    end

    test "passes through non-IPFS URIs unchanged" do
      assert "https://arweave.net/abc123" ==
               ArtworkResolver.resolve_uri("https://arweave.net/abc123")
    end

    test "passes through direct HTTPS URLs unchanged" do
      assert "https://example.com/image.png" ==
               ArtworkResolver.resolve_uri("https://example.com/image.png")
    end

    test "returns nil for nil input" do
      assert nil == ArtworkResolver.resolve_uri(nil)
    end
  end
end
