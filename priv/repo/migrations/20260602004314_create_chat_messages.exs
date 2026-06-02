defmodule SuchGalleryElixir.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :guest_name, :string, null: false
      add :body, :text, null: false
      add :gallery_id, references(:galleries, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:chat_messages, [:gallery_id, :inserted_at])
  end
end
