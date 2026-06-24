defmodule LuxApp.Schemas.Permission do
  @moduledoc """
  Schema for role-based permissions in the Web3 auth framework.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "permissions" do
    field :name, :string
    field :description, :string
    field :resource, :string
    field :action, :string
    field :role, :string

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          description: String.t() | nil,
          resource: String.t(),
          action: String.t(),
          role: String.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc false
  def changeset(permission, attrs) do
    permission
    |> cast(attrs, [:name, :description, :resource, :action, :role])
    |> validate_required([:name, :resource, :action, :role])
    |> unique_constraint([:name, :resource, :action])
  end
end
