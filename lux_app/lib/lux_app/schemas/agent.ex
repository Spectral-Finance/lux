defmodule LuxApp.Schemas.Agent do
  @moduledoc """
  A schema for an agent.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    filterable: [:name, :description, :goal, :template, :module],
    sortable: [:name, :inserted_at, :updated_at],
    default_limit: 20,
    default_order: %{order_by: [:inserted_at], order_directions: [:desc]}
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "agents" do
    field :name, :string
    field :description, :string
    field :goal, :string
    field :template, :string
    field :template_opts, :map, default: %{}
    field :module, :string
    field :position_x, :integer, default: 0
    field :position_y, :integer, default: 0
    field :scheduled_actions, :map, default: %{}
    field :signal_handlers, :map, default: %{}

    belongs_to :llm_config, LuxApp.Schemas.LlmConfig
    belongs_to :memory_config, LuxApp.Schemas.Memory

    many_to_many :prisms, LuxApp.Schemas.Prism, join_through: "agent_prisms"
    many_to_many :beams, LuxApp.Schemas.Beam, join_through: "agent_beams"
    many_to_many :lenses, LuxApp.Schemas.Lens, join_through: "agent_lenses"

    many_to_many :signal_schemas, LuxApp.Schemas.SignalSchema,
      join_through: "agent_signal_schemas"

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t(),
          description: String.t() | nil,
          goal: String.t() | nil,
          template: String.t() | nil,
          template_opts: map(),
          module: String.t() | nil,
          position_x: integer(),
          position_y: integer(),
          scheduled_actions: map(),
          signal_handlers: map(),
          llm_config_id: Ecto.UUID.t() | nil,
          memory_config_id: Ecto.UUID.t() | nil,
          llm_config: LuxApp.Schemas.LlmConfig.t() | nil | Ecto.Association.NotLoaded.t(),
          memory_config: LuxApp.Schemas.Memory.t() | nil | Ecto.Association.NotLoaded.t(),
          prisms: [LuxApp.Schemas.Prism.t()] | Ecto.Association.NotLoaded.t(),
          beams: [LuxApp.Schemas.Beam.t()] | Ecto.Association.NotLoaded.t(),
          lenses: [LuxApp.Schemas.Lens.t()] | Ecto.Association.NotLoaded.t(),
          signal_schemas: [LuxApp.Schemas.SignalSchema.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc false
  def changeset(agent, attrs) do
    agent
    |> cast(attrs, [
      :name,
      :description,
      :goal,
      :template,
      :template_opts,
      :module,
      :llm_config_id,
      :memory_config_id,
      :position_x,
      :position_y,
      :scheduled_actions,
      :signal_handlers
    ])
    |> validate_required([:name])
  end
end
