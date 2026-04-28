defmodule Lux.Integrations.SmartContractEvents.Subscription do
  @moduledoc "Event subscription management"

  defstruct [
    :id, :chain, :chain_config, :contract, :event, :event_signature,
    :from_block, :to_block, :filter, :webhook, :active,
    :last_processed_block, :created_at
  ]

  @doc "Create a new subscription"
  def create(attrs) do
    {:ok, %__MODULE__{
      id: generate_id(),
      chain: attrs.chain,
      chain_config: attrs.chain_config,
      contract: attrs.contract,
      event: attrs.event,
      event_signature: attrs.event_signature,
      from_block: attrs.from_block,
      to_block: attrs.to_block,
      filter: attrs.filter,
      webhook: attrs.webhook,
      active: true,
      last_processed_block: nil,
      created_at: DateTime.utc_now()
    }}
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
