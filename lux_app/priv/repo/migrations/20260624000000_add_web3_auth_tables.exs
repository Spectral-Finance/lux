defmodule LuxApp.Repo.Migrations.AddWeb3AuthTables do
  use Ecto.Migration

  def change do
    create table(:web3_auth_sessions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :wallet_address, :string, null: false
      add :chain_id, :integer, null: false, default: 1
      add :nonce, :string, null: false
      add :domain, :string, null: false
      add :statement, :text
      add :signature, :text, null: false
      add :issued_at, :utc_datetime_usec, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :revoked_at, :utc_datetime_usec
      add :metadata, :map, default: "{}"
      add :roles, {:array, :string}, default: []
      add :permissions, {:array, :map}, default: []
      timestamps(updated_at: false)
    end

    create unique_index(:web3_auth_sessions, [:wallet_address, :nonce])

    create table(:permissions, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :resource, :string, null: false
      add :action, :string, null: false
      add :role, :string, null: false
      timestamps()
    end

    create unique_index(:permissions, [:name, :resource, :action])

    create table(:role_assignments, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :wallet_address, :string, null: false
      add :role, :string, null: false
      add :granted_by, :string
      add :expires_at, :utc_datetime_usec
      add :metadata, :map, default: "{}"
      timestamps()
    end

    create unique_index(:role_assignments, [:wallet_address, :role])

    create table(:auth_audit_logs, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :wallet_address, :string
      add :event, :string, null: false
      add :details, :map, default: "{}"
      add :ip_address, :string
      add :user_agent, :text
      add :session_id, :uuid, references(:web3_auth_sessions, type: :uuid, on_delete: :nothing)
      timestamps()
    end

    create index(:auth_audit_logs, [:wallet_address])
    create index(:auth_audit_logs, [:event])
    create index(:auth_audit_logs, [:inserted_at])
  end
end
