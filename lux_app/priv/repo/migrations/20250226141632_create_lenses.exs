defmodule LuxApp.Repo.Migrations.CreateLenses do
  use Ecto.Migration

  def change do
    create table(:lenses, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :url, :string
      add :method, :string, default: "get"
      add :after_focus, :string

      # JSON fields for complex data
      add :params, :map, default: %{}
      add :headers, :map, default: %{}
      add :auth, :map, default: %{}
      add :schema, :map, default: %{}
      add :position_x, :integer, default: 0
      add :position_y, :integer, default: 0

      timestamps()
    end
  end
end
