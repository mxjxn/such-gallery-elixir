defmodule SuchGalleryElixir.Repo.Migrations.CreateGalleries do
  use Ecto.Migration

  def change do
    create table(:galleries) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :wall_color, :string, null: false, default: "#f5f5f0"
      add :frame_style, :string, null: false, default: "classic"
      add :owner_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create unique_index(:galleries, [:slug])
    create index(:galleries, [:owner_id])
  end
end
