defmodule Lux.Schemas.Coinbase.PortfolioSchema do
  @moduledoc """
  Schema definition for Coinbase Advanced Trade portfolio status and risk metrics.
  """
  use Lux.SignalSchema,
    name: "Coinbase Portfolio Schema",
    description: "Schema for aggregated portfolio balances, USD valuations, and risk exposure metrics",
    schema: %{
      type: :object,
      properties: %{
        total_balance_usd: %{
          type: :number,
          description: "Aggregate total mark-to-market portfolio value in USD"
        },
        unrealized_pnl: %{
          type: :number,
          description: "Total unrealized profit and loss in USD"
        },
        realized_pnl_24h: %{
          type: :number,
          description: "Realized 24-hour profit and loss in USD"
        },
        accounts: %{
          type: :array,
          description: "List of individual currency accounts and balances",
          items: %{
            type: :object,
            properties: %{
              currency: %{type: :string},
              available: %{type: :number},
              hold: %{type: :number},
              balance: %{type: :number}
            },
            required: ["currency", "balance"]
          }
        },
        allocations: %{
          type: :object,
          description: "Percentage asset allocation breakdown keyed by asset symbol"
        }
      },
      required: ["total_balance_usd"]
    }
end
