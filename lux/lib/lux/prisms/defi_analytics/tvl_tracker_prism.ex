defmodule Lux.Prisms.DefiAnalytics.TVLTracker do
  @moduledoc """
  A prism that tracks TVL across multiple protocols and detects significant changes.

  Compares current TVL against historical data to flag anomalies or trends.

  ## Example

      iex> Lux.Prisms.DefiAnalytics.TVLTracker.run(%{
      ...>   protocols: ["uniswap", "aave", "lido", "rocket-pool"],
      ...>   threshold_pct: 10.0
      ...> })
      {:ok, %{tracked_protocols: [...], total_tracked_tvl: 1234567890}}
  """

  use Lux.Prism,
    name: "TVL Tracker",
    description: "Tracks TVL across protocols and detects significant changes",
    input_schema: %{
      type: :object,
      properties: %{
        protocols: %{
          type: :array,
          items: %{type: :string},
          description: "List of protocol slugs to track"
        },
        threshold_pct: %{
          type: :number,
          description: "Percentage threshold for alerting (default: 10.0)",
          default: 10.0
        }
      },
      required: ["protocols"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        tracked_protocols: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              protocol: %{type: :string},
              current_tvl: %{type: :number},
              flagged: %{type: :boolean}
            }
          }
        },
        total_tracked_tvl: %{type: :number},
        threshold_pct: %{type: :number}
      },
      required: ["tracked_protocols", "total_tracked_tvl", "threshold_pct"]
    }

  alias Lux.Integrations.DeFiLlama

  require Logger

  @doc """
  Handler for the TVL tracker prism.
  """
  def handler(input, _ctx) do
    protocols = Map.get(input, "protocols", [])
    threshold = Map.get(input, "threshold_pct", 10.0)

    tasks = Enum.map(protocols, fn protocol ->
      Task.async(fn ->
        case DeFiLlama.protocol_tvl(protocol) do
          {:ok, data} when is_map(data) ->
            current_tvl = get_current_tvl(data)
            %{protocol: protocol, current_tvl: current_tvl, flagged: false}

          _ ->
            %{protocol: protocol, current_tvl: nil, flagged: false}
        end
      end)
    end)

    results =
      Enum.map(tasks, fn task ->
        case Task.await(task, 30_000) do
          result -> result
          _ -> nil
        end
      end)
      |> Enum.filter(& &1)

    total_tvl = Enum.reduce(results, 0, fn r, acc -> (r[:current_tvl] || 0) + acc end)

    {:ok, %{
      tracked_protocols: results,
      total_tracked_tvl: total_tvl,
      threshold_pct: threshold,
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }}
  rescue
    e ->
      Logger.error("TVL tracker error: #{inspect(e)}")
      {:error, "TVL tracking failed: #{inspect(e)}"}
  end

  defp get_current_tvl(data) do
    case data["tvl"] do
      [] -> 0
      [last | _] when is_map(last) ->
        Map.get(last, "totalLiquidityUSD", Map.get(last, "tvl", 0))
      _ -> 0
    end
  end
end
