defmodule LuxApp.Schemas.RoleAssignment do
  @moduledoc """
  Schema for assigning roles to wallet addresses.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "role_assignments" do
    field :wallet_address, :string
    field :role, :string
    field :granted_by, :string
    field :expires_at, :utc_datetime
    field :metadata, :map, default: %{}

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          wallet_address: String.t(),
          role: String.t(),
          granted_by: String.t() | nil,
          expires_at: NaiveDateTime.t() | nil,
          metadata: map(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc false
  def changeset(assignment, attrs) do
    assignment
    |> cast(attrs, [:wallet_address, :role, :granted_by, :expires_at, :metadata])
    |> validate_required([:wallet_address, :role])
    |> unique_constraint([:wallet_address, :role])
  end
end
