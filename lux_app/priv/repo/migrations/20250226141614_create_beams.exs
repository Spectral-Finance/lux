defmodule LuxApp.Repo.Migrations.CreateBeams do
  use Ecto.Migration

  def change do
    create table(:beams, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :module, :string
      add :generate_execution_log, :boolean, default: false

      # JSON fields for complex data
      add :input_schema, :map, default: %{}
      add :output_schema, :map, default: %{}
      add :position_x, :integer, default: 0
      add :position_y, :integer, default: 0

      timestamps()
    end
  end
end
