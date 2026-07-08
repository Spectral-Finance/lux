defmodule LuxApp.Repo.Migrations.CreateMemories do
  use Ecto.Migration

  def change do
    create table(:memories, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :backend, :string, null: false

      # For memory entries
      add :content, :text
      add :memory_type, :string
      add :metadata, :map, default: %{}
      add :position_x, :integer, default: 0
      add :position_y, :integer, default: 0

      timestamps()
    end

    # Memory entries table for storing actual memory content
    create table(:memory_entries, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :memory_id, references(:memories, type: :uuid, on_delete: :delete_all), null: false
      add :content, :text
      add :memory_type, :string
      add :metadata, :map, default: %{}
      add :entry_timestamp, :utc_datetime

      timestamps()
    end

    create index(:memory_entries, [:memory_id])
    create index(:memory_entries, [:memory_type])
    create index(:memory_entries, [:entry_timestamp])
  end
end
