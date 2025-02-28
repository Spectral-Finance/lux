defmodule LuxApp.Repo.Migrations.CreateEdges do
  use Ecto.Migration

  def change do
    create table(:edges, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :source_id, :uuid, null: false
      add :source_type, :string, null: false
      add :source_port, :string
      add :target_id, :uuid, null: false
      add :target_type, :string, null: false
      add :target_port, :string
      add :label, :string
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:edges, [:source_id, :source_type])
    create index(:edges, [:target_id, :target_type])

    create unique_index(:edges, [:source_id, :source_port, :target_id, :target_port],
             where: "source_port IS NOT NULL AND target_port IS NOT NULL",
             name: :unique_edge_with_ports_index
           )
  end
end
