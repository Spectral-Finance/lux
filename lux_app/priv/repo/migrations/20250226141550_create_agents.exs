defmodule LuxApp.Repo.Migrations.CreateAgents do
  use Ecto.Migration

  def change do
    create table(:agents, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :goal, :text
      add :template, :string
      add :template_opts, :map, default: %{}
      add :module, :string
      add :llm_config_id, :uuid, null: true
      add :memory_config_id, :uuid, null: true
      add :position_x, :integer, default: 0
      add :position_y, :integer, default: 0

      # JSON fields for complex data
      add :scheduled_actions, :map, default: %{}
      add :signal_handlers, :map, default: %{}

      timestamps()
    end
  end
end
