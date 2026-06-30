defmodule LuxApp.Repo.Migrations.CreateLlmConfigs do
  use Ecto.Migration

  def change do
    create table(:llm_configs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string
      add :provider, :string, null: false
      add :model, :string, null: false
      add :temperature, :float, default: 0.7
      add :max_tokens, :integer

      # JSON fields for provider-specific configuration
      add :provider_config, :map, default: %{}
      add :position_x, :integer, default: 0
      add :position_y, :integer, default: 0

      timestamps()
    end

    create index(:llm_configs, [:provider])
    create index(:llm_configs, [:model])
  end
end
