defmodule LuxApp.Schemas.Prism do
  @moduledoc """
  A schema for a prism.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    filterable: [:name, :description, :handler],
    sortable: [:name, :inserted_at, :updated_at],
    default_limit: 20,
    default_order: %{order_by: [:inserted_at], order_directions: [:desc]}
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "prisms" do
    field :name, :string
    field :description, :string
    field :handler, :string
    field :examples, {:array, :string}, default: []
    field :input_schema, :map, default: %{}
    field :output_schema, :map, default: %{}
    field :position_x, :integer, default: 0
    field :position_y, :integer, default: 0

    many_to_many :agents, LuxApp.Schemas.Agent, join_through: "agent_prisms"

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          description: String.t() | nil,
          handler: String.t() | nil,
          examples: [String.t()],
          input_schema: map(),
          output_schema: map(),
          position_x: integer(),
          position_y: integer(),
          agents: [LuxApp.Schemas.Agent.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc false
  def changeset(prism, attrs) do
    prism
    |> cast(attrs, [
      :name,
      :description,
      :handler,
      :examples,
      :input_schema,
      :output_schema,
      :position_x,
      :position_y
    ])
    |> validate_required([:name])
  end
end
