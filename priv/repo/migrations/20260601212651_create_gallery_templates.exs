defmodule SuchGalleryElixir.Repo.Migrations.CreateGalleryTemplates do
  use Ecto.Migration

  def change do
    create table(:gallery_templates) do
      add :slug, :string, null: false
      add :name, :string, null: false
      add :slot_count, :integer, null: false
      add :layout, :string, null: false, default: "rectangular"
      add :width, :float, null: false
      add :depth, :float, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:gallery_templates, [:slug])

    create table(:layout_slots) do
      add :slot_index, :integer, null: false
      add :wall, :string, null: false, default: "back"
      add :u, :float, null: false
      add :v, :float, null: false, default: 0.5
      add :rotation_y, :float, null: false, default: 0.0
      add :scale, :float, null: false, default: 1.0
      add :template_id, references(:gallery_templates, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:layout_slots, [:template_id, :wall, :slot_index])
    create index(:layout_slots, [:template_id])
  end
end
