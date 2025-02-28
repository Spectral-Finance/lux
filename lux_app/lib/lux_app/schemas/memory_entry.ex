defmodule LuxApp.Schemas.MemoryEntry do
  @moduledoc """
  A schema for a memory entry.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @derive {
    Flop.Schema,
    filterable: [:memory_type, :entry_timestamp, :memory_id],
    sortable: [:memory_type, :entry_timestamp, :inserted_at, :updated_at],
    default_limit: 20,
    default_order: %{order_by: [:entry_timestamp], order_directions: [:desc]}
  }

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "memory_entries" do
    field :content, :string
    field :memory_type, :string
    field :metadata, :map, default: %{}
    field :entry_timestamp, :utc_datetime

    belongs_to :memory, LuxApp.Schemas.Memory

    timestamps()
  end

  @type t :: %__MODULE__{
          id: Ecto.UUID.t(),
          content: String.t() | nil,
          memory_type: String.t() | nil,
          metadata: map(),
          entry_timestamp: DateTime.t() | nil,
          memory_id: Ecto.UUID.t(),
          memory: LuxApp.Schemas.Memory.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  @doc false
  def changeset(memory_entry, attrs) do
    memory_entry
    |> cast(attrs, [:content, :memory_type, :metadata, :entry_timestamp, :memory_id])
    |> validate_required([:memory_id])
    |> foreign_key_constraint(:memory_id)
  end
end
