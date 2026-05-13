defmodule Lux.Prisms.SmartContractEvents.CreateSubscription do
  @moduledoc """
  Creates a smart contract event subscription in the Lux event monitor.
  """

  use Lux.Prism,
    name: "Smart Contract Event Subscription",
    description: "Registers a contract address, topic filters, decoder metadata, and optional webhook.",
    input_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string, description: "Optional stable subscription id"},
        name: %{type: :string, description: "Human-readable subscription name"},
        chain_id: %{type: :integer, description: "EVM chain id", default: 1},
        address: %{type: :string, description: "Contract address to monitor"},
        topics: %{
          type: :array,
          description: "Optional topic0-topic3 filters",
          items: %{type: :string}
        },
        filters: %{type: :object, description: "Optional transaction, data, and block filters"},
        event_abi: %{type: :array, description: "Optional ABI event definitions used to decode matching logs"},
        start_block: %{type: :integer, description: "Historical sync start block"},
        webhook_url: %{type: :string, description: "Webhook URL for matching events"}
      }
    },
    output_schema: %{
      type: :object,
      properties: %{
        id: %{type: :string},
        chain_id: %{type: :integer},
        address: %{type: :string}
      },
      required: ["id", "chain_id"]
    }

  def handler(input, _context) do
    Lux.EventMonitor.subscribe(input)
  end
end
