defmodule LuxApp.Schemas.AuthAuditLog do
  @moduledoc """
  Schema for auditing authentication events.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "auth_audit_logs" do
    field :wallet_address, :string
    field :event, :string
    field :details, :map, default: %{}
    field :ip_address, :string
    field :user_agent, :string
    field :session_id, :string

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          wallet_address: String.t() | nil,
          event: String.t(),
          details: map(),
          ip_address: String.t() | nil,
          user_agent: String.t() | nil,
          session_id: Ecto.UUID.t() | nil,
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc false
  def changeset(log, attrs) do
    log
    |> cast(attrs, [:wallet_address, :event, :details, :ip_address, :user_agent, :session_id])
    |> validate_required([:event])
  end
end
