defmodule LuxApp.Repo.Migrations.CreatePrisms do
  use Ecto.Migration

  def change do
    create table(:prisms, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :handler, :string

      # JSON fields for complex data
      add :examples, {:array, :string}, default: []
      add :input_schema, :map, default: %{}
      add :output_schema, :map, default: %{}
      add :position_x, :integer, default: 0
      add :position_y, :integer, default: 0

      timestamps()
    end
  end
end
