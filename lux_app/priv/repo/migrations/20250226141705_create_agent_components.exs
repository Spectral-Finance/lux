defmodule LuxApp.Repo.Migrations.CreateAgentComponents do
  use Ecto.Migration

  def change do
    # Join table for agents and prisms
    create table(:agent_prisms, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :agent_id, references(:agents, type: :uuid, on_delete: :delete_all), null: false
      add :prism_id, references(:prisms, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:agent_prisms, [:agent_id, :prism_id])
    create index(:agent_prisms, [:prism_id])

    # Join table for agents and beams
    create table(:agent_beams, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :agent_id, references(:agents, type: :uuid, on_delete: :delete_all), null: false
      add :beam_id, references(:beams, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:agent_beams, [:agent_id, :beam_id])
    create index(:agent_beams, [:beam_id])

    # Join table for agents and lenses
    create table(:agent_lenses, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :agent_id, references(:agents, type: :uuid, on_delete: :delete_all), null: false
      add :lens_id, references(:lenses, type: :uuid, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:agent_lenses, [:agent_id, :lens_id])
    create index(:agent_lenses, [:lens_id])

    # Table for signal schemas that agents can accept
    create table(:signal_schemas, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :schema, :map, default: %{}

      timestamps()
    end

    # Join table for agents and signal schemas
    create table(:agent_signal_schemas, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :agent_id, references(:agents, type: :uuid, on_delete: :delete_all), null: false

      add :signal_schema_id, references(:signal_schemas, type: :uuid, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create unique_index(:agent_signal_schemas, [:agent_id, :signal_schema_id])
    create index(:agent_signal_schemas, [:signal_schema_id])
  end
end
