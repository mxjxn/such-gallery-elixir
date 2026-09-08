defmodule SuchGalleryElixir.Repo.Migrations.AddExhibitionPublications do
  use Ecto.Migration

  def change do
    alter table(:artworks) do
      add(:chain_id, :integer)
      add(:contract_address, :string)
      add(:token_id, :string)
      add(:canonical_media_uri, :text)
    end

    alter table(:artwork_placements) do
      add(:caption, :text)
    end

    alter table(:galleries) do
      add(:published_revision, :integer)
    end

    create table(:gallery_publications) do
      add(:gallery_id, references(:galleries, on_delete: :delete_all), null: false)
      add(:revision, :integer, null: false)
      add(:manifest, :map, null: false)
      add(:published_at, :utc_datetime_usec, null: false)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(unique_index(:gallery_publications, [:gallery_id, :revision]))
    create(index(:gallery_publications, [:gallery_id, :published_at]))
  end
end