defmodule Lux.Schemas.EventMonitor.ContractEventSchema do
  @moduledoc """
  Signal schema for smart contract events.

  Defines the structure for contract event signals that flow through the
  Lux agent system. Events captured by the monitoring system can be
  wrapped in this schema for validation and type-safe processing.

  ## Schema

  ```json
  {
    "event_name": "Transfer",
    "address": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "chain_id": 1,
    "block_number": 18000000,
    "transaction_hash": "0x...",
    "log_index": 0,
    "decoded_params": {
      "from": "0x...",
      "to": "0x...",
      "value": 1000000
    },
    "timestamp": 1234567890
  }
  ```
  """

  use Lux.SignalSchema,
    name: "ContractEvent",
    version: "1.0.0",
    description: "Smart contract event captured by the event monitoring system",
    tags: ["web3", "events", "smart-contract"],
    schema: %{
      type: :object,
      properties: %{
        event_name: %{
          type: :string,
          description: "Name of the emitted event"
        },
        address: %{
          type: :string,
          description: "Contract address that emitted the event"
        },
        chain_id: %{
          type: :integer,
          description: "Chain identifier where the event was emitted"
        },
        block_number: %{
          type: :integer,
          description: "Block number containing the event"
        },
        transaction_hash: %{
          type: :string,
          description: "Transaction hash that triggered the event"
        },
        log_index: %{
          type: :integer,
          description: "Log index within the block"
        },
        decoded_params: %{
          type: :object,
          description: "Decoded event parameters"
        },
        data: %{
          type: :string,
          description: "Raw event data"
        },
        topics: %{
          type: :array,
          items: %{type: :string},
          description: "Event topic hashes"
        },
        timestamp: %{
          type: :integer,
          description: "Block timestamp"
        },
        removed: %{
          type: :boolean,
          description: "Whether the event was removed due to chain reorganization"
        }
      },
      required: ["address", "chain_id", "block_number", "transaction_hash"]
    }
end
