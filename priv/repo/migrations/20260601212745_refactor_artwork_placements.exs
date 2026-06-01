defmodule SuchGalleryElixir.Repo.Migrations.RefactorArtworkPlacements do
  use Ecto.Migration

  def change do
    drop table(:artwork_placements)
    drop table(:rooms)

    create table(:artwork_placements) do
      add :kind, :string, null: false, default: "slot"
      add :display_order, :integer, null: false
      add :override_wall, :string
      add :override_u, :float
      add :override_v, :float
      add :override_rotation_y, :float
      add :override_scale, :float
      add :gallery_id, references(:galleries, on_delete: :delete_all), null: false
      add :artwork_id, references(:artworks, on_delete: :delete_all), null: false
      add :layout_slot_id, references(:layout_slots, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:artwork_placements, [:gallery_id])
    create index(:artwork_placements, [:artwork_id])

    create unique_index(:artwork_placements, [:gallery_id, :layout_slot_id],
             where: "layout_slot_id IS NOT NULL"
           )
  end
end
