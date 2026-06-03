defmodule SuchGalleryElixir.Repo.Migrations.AddArtworkSourceAndMetadataFields do
  use Ecto.Migration

  def change do
    alter table(:artworks) do
      # How this artwork was sourced
      add :source_type, :string, null: false, default: "url"
      # Raw input used to create this artwork (dedup key)
      add :source_ref, :string

      # Cached metadata
      add :description, :text
      add :animation_url, :string
      add :metadata_status, :string, null: false, default: "pending"

      # Listing context (auction house, etc) — different shape per source_type
      add :listing_meta, :map
    end

    create index(:artworks, [:source_ref])
    create index(:artworks, [:metadata_status])
  end
end
