defmodule Lux.Prisms.Web3.MultiChainDataAggregationPrism do
  @moduledoc """
  Creates a safe multi-chain EVM data aggregation plan.

  The prism prepares JSON-RPC read requests for latest blocks and event logs
  across EVM chains. It does not require private keys and never signs or
  broadcasts transactions.
  """

  use Lux.Prism,
    name: "Multi-Chain Data Aggregation",
    description: "Builds multi-chain EVM block and event aggregation plans",
    input_schema: %{
      type: :object,
      properties: %{
        chains: %{
          type: :array,
          description: "EVM chains to query, e.g. ethereum, polygon, base",
          items: %{type: :string},
          default: ["ethereum", "polygon", "base"]
        },
        event_filters: %{
          type: :array,
          description: "Optional contract event filters to build eth_getLogs requests for",
          items: %{type: :object}
        },
        poll_interval_ms: %{
          type: :integer,
          description: "Polling interval for generated event plans",
          default: 12_000
        }
      },
      required: ["chains"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        status: %{type: :string},
        latest_block_requests: %{type: :array},
        subscription_plan: %{type: :object},
        retention: %{type: :object}
      },
      required: ["status", "latest_block_requests", "subscription_plan", "retention"]
    }

  alias Lux.Integrations.MultiChain.Aggregator

  def handler(%{chains: chains} = input, _ctx) do
    filters = Map.get(input, :event_filters, [])
    poll_interval_ms = Map.get(input, :poll_interval_ms, 12_000)

    with {:ok, latest_block_requests} <- Aggregator.latest_block_requests(chains),
         {:ok, subscription_plan} <-
           Aggregator.subscription_plan(chains, filters, %{poll_interval_ms: poll_interval_ms}) do
      {:ok,
       %{
         status: "planned",
         latest_block_requests: latest_block_requests,
         subscription_plan: subscription_plan,
         retention: subscription_plan.retention
       }}
    end
  end
end
