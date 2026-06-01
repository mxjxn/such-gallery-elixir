defmodule SuchGalleryElixir.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms) do
      add :layout, :string, null: false, default: "rectangular"
      add :width, :float, null: false
      add :depth, :float, null: false
      add :gallery_id, references(:galleries, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:rooms, [:gallery_id])
  end
end
