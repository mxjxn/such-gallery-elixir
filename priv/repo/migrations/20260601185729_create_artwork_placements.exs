defmodule SuchGalleryElixir.Repo.Migrations.CreateArtworkPlacements do
  use Ecto.Migration

  def change do
    create table(:artwork_placements) do
      add :artwork_url, :string, null: false
      add :title, :string
      add :artist, :string
      add :position_x, :float, null: false, default: 0.0
      add :position_y, :float, null: false, default: 0.0
      add :position_z, :float, null: false, default: 0.0
      add :rotation, :float, null: false, default: 0.0
      add :scale, :float, null: false, default: 1.0
      add :wall, :string, null: false, default: "back"
      add :room_id, references(:rooms, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:artwork_placements, [:room_id])
  end
end
