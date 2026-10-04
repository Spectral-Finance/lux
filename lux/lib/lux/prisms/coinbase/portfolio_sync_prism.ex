defmodule Lux.Prisms.Coinbase.PortfolioSyncPrism do
  @moduledoc """
  Prism for synchronizing Coinbase portfolio balances, mark-to-market valuations, and risk metrics.
  """
  use Lux.Prism,
    name: "Coinbase Portfolio Sync Prism",
    description: "Fetches live accounts, synchronizes mark-to-market asset values, and calculates risk allocations",
    input_schema: %{
      type: :object,
      properties: %{
        max_concentration_pct: %{
          type: :number,
          description: "Max single asset concentration threshold"
        },
        max_position_usd: %{
          type: :number,
          description: "Max single position dollar value"
        }
      }
    }

  require Logger
  import Lux.Python

  @impl true
  def handler(input, _ctx) do
    max_concentration = Map.get(input, "max_concentration_pct", 40.0)
    max_position = Map.get(input, "max_position_usd", 100_000.0)

    python_result =
      python variables: %{
               max_concentration: max_concentration,
               max_position: max_position
             } do
        ~PY"""
        from lux.coinbase.pipeline import CoinbasePipeline

        pipeline = CoinbasePipeline(
            max_concentration_pct=max_concentration,
            max_position_usd=max_position,
        )
        summary = pipeline.sync_portfolio()
        summary.model_dump()
        """
      end

    case python_result do
      %{"error" => err} -> {:error, err}
      result when is_map(result) -> {:ok, result}
      other -> {:error, "Unexpected portfolio sync response: #{inspect(other)}"}
    end
  end
end
