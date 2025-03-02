defmodule Lux.Repo.Migrations.CreateJobOpenings do
  use Ecto.Migration

  def change do
    create table(:job_openings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text, null: false
      add :status, :string, null: false, default: "open"
      add :company_contract_address, :text

      timestamps()
    end

    create index(:job_openings, [:status])
    create index(:job_openings, [:name])
  end
end
