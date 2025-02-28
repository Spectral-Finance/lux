defmodule LuxApp.Schemas.Memory do
  @moduledoc """
  A schema for a memory.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    filterable: [:name, :backend, :memory_type],
    sortable: [:name, :backend, :inserted_at, :updated_at],
    default_limit: 20,
    default_order: %{order_by: [:inserted_at], order_directions: [:desc]}
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "memories" do
    field :name, :string
    field :backend, :string
    field :content, :string
    field :memory_type, :string
    field :metadata, :map, default: %{}
    field :position_x, :integer, default: 0
    field :position_y, :integer, default: 0

    has_many :memory_entries, LuxApp.Schemas.MemoryEntry
    has_many :agents, LuxApp.Schemas.Agent, foreign_key: :memory_config_id

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t() | nil,
          backend: String.t(),
          content: String.t() | nil,
          memory_type: String.t() | nil,
          metadata: map(),
          position_x: integer(),
          position_y: integer(),
          memory_entries: [LuxApp.Schemas.MemoryEntry.t()] | Ecto.Association.NotLoaded.t(),
          agents: [LuxApp.Schemas.Agent.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc false
  def changeset(memory, attrs) do
    memory
    |> cast(attrs, [:name, :backend, :content, :memory_type, :metadata, :position_x, :position_y])
    |> validate_required([:backend])
  end
end
