defmodule SuchGalleryElixir.Galleries.InputParserTest do
  use SuchGalleryElixir.DataCase, async: true

  alias SuchGalleryElixir.Galleries.InputParser

  describe "parse/1" do
    test "parses plain HTTP image URL" do
      assert {:ok, {:url, "https://example.com/art.png"}} =
               InputParser.parse("https://example.com/art.png")
    end

    test "parses HTTPS image URL" do
      assert {:ok, {:url, "https://ipfs.io/ipfs/QmHash"}} =
               InputParser.parse("https://ipfs.io/ipfs/QmHash")
    end

    test "parses NFT ref with ethereum chain" do
      assert {:ok, {:nft_ref, ref}} =
               InputParser.parse("nft:1:0xabc123def456def456def456def456def456abcd:42")

      assert String.starts_with?(ref, "nft:1:")
    end

    test "parses NFT ref with Base chain (8453)" do
      assert {:ok, {:nft_ref, ref}} =
               InputParser.parse("nft:8453:0x000000000000000000000000000000000000ABC:100")

      assert String.starts_with?(ref, "nft:8453:")
    end

    test "parses auction listing ref" do
      assert {:ok, {:auction_listing, ref}} =
               InputParser.parse("auction:1:0xabc123def456def456def456def456def456abcd:7:99")

      assert String.starts_with?(ref, "auction:1:")
    end

    test "rejects empty string" do
      assert {:error, :empty_input} = InputParser.parse("")
    end

    test "rejects bare text" do
      assert {:error, :invalid_input} = InputParser.parse("some random text")
    end

    test "rejects URL without protocol" do
      assert {:error, :invalid_input} = InputParser.parse("example.com/art.png")
    end

    test "rejects incomplete NFT ref (missing token_id)" do
      assert {:error, :invalid_nft_ref} =
               InputParser.parse("nft:1:0xabc123def456def456def456def456def456abcd")
    end

    test "rejects NFT ref with invalid chain" do
      assert {:error, :invalid_chain} =
               InputParser.parse("nft:999:0xabc123def456def456def456def456def456abcd:1")
    end

    test "rejects NFT ref with invalid address" do
      assert {:error, :invalid_address} =
               InputParser.parse("nft:1:notanaddress:1")
    end

    test "rejects auction ref with missing listing_id" do
      assert {:error, :invalid_auction_format} =
               InputParser.parse("auction:1:0xabc123def456def456def456def456def456abcd:7")
    end
  end

  describe "supported chains" do
    test "accepts chain 1 (mainnet)" do
      assert {:ok, {:nft_ref, _}} =
               InputParser.parse("nft:1:0x0000000000000000000000000000000000000001:1")
    end

    test "accepts chain 8453 (Base)" do
      assert {:ok, {:nft_ref, _}} =
               InputParser.parse("nft:8453:0x0000000000000000000000000000000000000001:1")
    end

    test "rejects unsupported chain" do
      assert {:error, :invalid_chain} =
               InputParser.parse("nft:137:0x0000000000000000000000000000000000000001:1")
    end
  end
end
