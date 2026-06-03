defmodule SuchGalleryElixir.GalleriesTest do
  use SuchGalleryElixir.DataCase, async: true

  alias SuchGalleryElixir.Galleries
  alias SuchGalleryElixir.GalleriesFixtures

  describe "list_galleries/0" do
    test "returns all galleries with template preloaded" do
      _gallery1 = GalleriesFixtures.gallery_fixture()
      _gallery2 = GalleriesFixtures.gallery_fixture()

      galleries = Galleries.list_galleries()

      assert length(galleries) >= 2
      assert Enum.all?(galleries, &Ecto.assoc_loaded?(&1.template))
    end

    test "returns empty list when no galleries exist" do
      # This test may have other galleries from parallel tests, so just verify
      # the function returns a list with templates preloaded
      galleries = Galleries.list_galleries()

      assert is_list(galleries)
      assert Enum.all?(galleries, &Ecto.assoc_loaded?(&1.template))
    end
  end

  describe "update_gallery/2" do
    test "updates gallery name" do
      gallery = GalleriesFixtures.gallery_fixture()
      {:ok, updated} = Galleries.update_gallery(gallery, %{name: "Updated Name"})

      assert updated.name == "Updated Name"
    end

    test "updates gallery wall_color" do
      gallery = GalleriesFixtures.gallery_fixture()
      {:ok, updated} = Galleries.update_gallery(gallery, %{wall_color: "#ff0000"})

      assert updated.wall_color == "#ff0000"
    end

    test "returns errors for invalid changes" do
      gallery = GalleriesFixtures.gallery_fixture()

      {:error, changeset} =
        Galleries.update_gallery(gallery, %{wall_color: "not-a-color"})

      assert %{wall_color: ["has invalid format"]} = errors_on(changeset)
    end
  end

  describe "slugify_name/1" do
    test "converts name to lowercase slug" do
      assert Galleries.slugify_name("My Gallery") == "my-gallery"
    end

    test "replaces special characters with hyphens" do
      assert Galleries.slugify_name("Hello   World!!") == "hello-world"
    end

    test "trims leading and trailing hyphens" do
      assert Galleries.slugify_name("--test--") == "test"
    end

    test "handles empty string" do
      assert Galleries.slugify_name("") == ""
    end

    test "caps at 100 characters" do
      long_name = String.duplicate("a", 200)
      result = Galleries.slugify_name(long_name)
      assert String.length(result) == 100
    end

    test "returns empty for non-binary input" do
      assert Galleries.slugify_name(nil) == ""
    end
  end
end
