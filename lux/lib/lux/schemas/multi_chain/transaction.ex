defmodule Lux.Schemas.MultiChain.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :chain_id, :string
    field :tx_hash, :string
    field :contract_address, :binary
    field :block_number, :integer
    field :dedupe_key, :string
  end

  def changeset(schema, params) do
    schema
    |> cast(params, [:chain_id, :tx_hash, :contract_address, :block_number, :dedupe_key])
    |> validate_required([:chain_id, :tx_hash, :block_number])
  end
end
