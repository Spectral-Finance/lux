defmodule LuxApp.Schemas.Lens do
  @moduledoc """
  A schema for a lens.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    filterable: [:name, :description, :url, :method],
    sortable: [:name, :inserted_at, :updated_at],
    default_limit: 20,
    default_order: %{order_by: [:inserted_at], order_directions: [:desc]}
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "lenses" do
    field :name, :string
    field :description, :string
    field :url, :string
    field :method, :string, default: "get"
    field :after_focus, :string
    field :params, :map, default: %{}
    field :headers, :map, default: %{}
    field :auth, :map, default: %{}
    field :schema, :map, default: %{}
    field :position_x, :integer, default: 0
    field :position_y, :integer, default: 0

    many_to_many :agents, LuxApp.Schemas.Agent, join_through: "agent_lenses"

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          description: String.t() | nil,
          url: String.t() | nil,
          method: String.t(),
          after_focus: String.t() | nil,
          params: map(),
          headers: map(),
          auth: map(),
          schema: map(),
          position_x: integer(),
          position_y: integer(),
          agents: [LuxApp.Schemas.Agent.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc false
  def changeset(lens, attrs) do
    lens
    |> cast(attrs, [
      :name,
      :description,
      :url,
      :method,
      :after_focus,
      :params,
      :headers,
      :auth,
      :schema,
      :position_x,
      :position_y
    ])
    |> validate_required([:name])
  end
end
