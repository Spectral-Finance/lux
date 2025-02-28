defmodule LuxApp.Schemas.SignalSchema do
  @moduledoc """
  A schema for a signal.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    filterable: [:name, :description],
    sortable: [:name, :inserted_at, :updated_at],
    default_limit: 20,
    default_order: %{order_by: [:inserted_at], order_directions: [:desc]}
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "signal_schemas" do
    field :name, :string
    field :description, :string
    field :schema, :map, default: %{}

    many_to_many :agents, LuxApp.Schemas.Agent, join_through: "agent_signal_schemas"

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          description: String.t() | nil,
          schema: map(),
          agents: [LuxApp.Schemas.Agent.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc false
  def changeset(signal_schema, attrs) do
    signal_schema
    |> cast(attrs, [:name, :description, :schema])
    |> validate_required([:name])
  end
end
