defmodule LuxApp.Schemas.Edge do
  @moduledoc """
  A schema for an edge.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    filterable: [:source_id, :source_type, :target_id, :target_type, :label],
    sortable: [:source_type, :target_type, :label, :inserted_at, :updated_at],
    default_limit: 20,
    default_order: %{order_by: [:inserted_at], order_directions: [:desc]}
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "edges" do
    field :source_id, :binary_id
    field :source_type, :string
    field :source_port, :string
    field :target_id, :binary_id
    field :target_type, :string
    field :target_port, :string
    field :label, :string
    field :metadata, :map, default: %{}

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          source_id: Ecto.UUID.t(),
          source_type: String.t(),
          source_port: String.t() | nil,
          target_id: Ecto.UUID.t(),
          target_type: String.t(),
          target_port: String.t() | nil,
          label: String.t() | nil,
          metadata: map(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc false
  def changeset(edge, attrs) do
    edge
    |> cast(attrs, [
      :source_id,
      :source_type,
      :source_port,
      :target_id,
      :target_type,
      :target_port,
      :label,
      :metadata
    ])
    |> validate_required([:source_id, :source_type, :target_id, :target_type])
    |> unique_constraint([:source_id, :source_port, :target_id, :target_port],
      name: :unique_edge_with_ports_index,
      message: "Edge with these ports already exists"
    )
  end
end
