defmodule Lux.Schemas.MultiChain.Log do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :chain_id, :string
    field :address, :binary
    field :block_number, :integer
    field :tx_hash, :string
    field :log_index, :integer
    field :dedupe_key, :string
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [:chain_id, :address, :block_number, :tx_hash, :log_index, :dedupe_key])
    |> validate_required([:chain_id, :address, :block_number, :tx_hash, :log_index])
  end
end
