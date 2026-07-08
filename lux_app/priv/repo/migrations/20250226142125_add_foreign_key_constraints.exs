defmodule LuxApp.Repo.Migrations.AddForeignKeyConstraints do
  use Ecto.Migration

  def change do
    # Add foreign key constraints to agents table
    alter table(:agents) do
      modify :llm_config_id, references(:llm_configs, type: :uuid, on_delete: :nilify_all)
      modify :memory_config_id, references(:memories, type: :uuid, on_delete: :nilify_all)
    end

    create index(:agents, [:llm_config_id])
    create index(:agents, [:memory_config_id])

    # Add foreign key constraints to memory_entries table
    # (This is already handled in the create_memories migration)

    # Add foreign key constraints to agent_components tables
    # (These are already handled in the create_agent_components migration)
  end
end
