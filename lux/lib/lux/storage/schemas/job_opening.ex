defmodule Lux.Storage.Schemas.JobOpening do
  @moduledoc """
  Schema for storing job openings.

  Contains job name, description, status, company contract address, and timestamps.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @typedoc """
  Type that represents a JobOpening schema struct.
  """
  @type t :: %__MODULE__{
    id: Ecto.UUID.t() | nil,
    name: String.t() | nil,
    description: String.t() | nil,
    status: String.t() | nil,
    company_contract_address: String.t() | nil,
    inserted_at: DateTime.t() | nil,
    updated_at: DateTime.t() | nil
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "job_openings" do
    field :name, :string
    field :description, :string
    field :status, :string, default: "open"
    field :company_contract_address, :string

    timestamps()
  end

  @doc """
  Creates a changeset for job openings.

  ## Parameters

  - `schema` - The schema to create a changeset for
  - `attrs` - The attributes to cast

  ## Returns

  - A changeset
  """
  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:name, :description, :status, :company_contract_address])
    |> validate_required([:name, :description])
    |> validate_inclusion(:status, ["open", "closed"])
  end
end
