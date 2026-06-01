defmodule SuchGalleryElixir.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :wallet_address, :string, null: false
      add :display_name, :string
      add :avatar_color, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:wallet_address])
  end
end
