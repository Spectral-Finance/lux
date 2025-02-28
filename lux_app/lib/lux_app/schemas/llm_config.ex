defmodule LuxApp.Schemas.LlmConfig do
  @moduledoc """
  A schema for a LLM config.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    filterable: [:name, :provider, :model],
    sortable: [:name, :provider, :model, :inserted_at, :updated_at],
    default_limit: 20,
    default_order: %{order_by: [:inserted_at], order_directions: [:desc]}
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "llm_configs" do
    field :name, :string
    field :provider, :string
    field :model, :string
    field :temperature, :float, default: 0.7
    field :max_tokens, :integer
    field :provider_config, :map, default: %{}
    field :position_x, :integer, default: 0
    field :position_y, :integer, default: 0

    has_many :agents, LuxApp.Schemas.Agent, foreign_key: :llm_config_id

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          name: String.t() | nil,
          provider: String.t(),
          model: String.t(),
          temperature: float(),
          max_tokens: integer() | nil,
          provider_config: map(),
          position_x: integer(),
          position_y: integer(),
          agents: [LuxApp.Schemas.Agent.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc false
  def changeset(llm_config, attrs) do
    llm_config
    |> cast(attrs, [
      :name,
      :provider,
      :model,
      :temperature,
      :max_tokens,
      :provider_config,
      :position_x,
      :position_y
    ])
    |> validate_required([:provider, :model])
    |> validate_number(:temperature, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
  end
end
