defmodule SuchGalleryElixir.Repo.Migrations.CreateArtworks do
  use Ecto.Migration

  def change do
    create table(:artworks) do
      add :artwork_url, :string, null: false
      add :title, :string
      add :artist, :string
      add :external_id, :string
      add :aspect_ratio, :float

      timestamps(type: :utc_datetime)
    end

    create unique_index(:artworks, [:external_id], where: "external_id IS NOT NULL")
  end
end
