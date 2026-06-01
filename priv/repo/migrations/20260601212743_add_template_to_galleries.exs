defmodule SuchGalleryElixir.Repo.Migrations.AddTemplateToGalleries do
  use Ecto.Migration

  def change do
    alter table(:galleries) do
      add :template_id, references(:gallery_templates, on_delete: :restrict), null: false
      add :width_override, :float
      add :depth_override, :float
    end

    create index(:galleries, [:template_id])
  end
end
