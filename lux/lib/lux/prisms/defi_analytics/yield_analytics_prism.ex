defmodule Lux.Prisms.DefiAnalytics.YieldAnalytics do
  @moduledoc """
  A prism that analyzes yield farming opportunities and ranks them
  by risk-adjusted returns.

  ## Example

      iex> Lux.Prisms.DefiAnalytics.YieldAnalytics.run(%{
      ...>   chain: "Ethereum",
      ...>   min_apy: 5.0,
      ...>   max_apr: 500.0
      ...> })
      {:ok, %{opportunities: [...]}}
  """

  use Lux.Prism,
    name: "Yield Analytics",
    description: "Analyzes and ranks DeFi yield farming opportunities",
    input_schema: %{
      type: :object,
      properties: %{
        chain: %{
          type: :string,
          description: "Filter by blockchain (e.g., 'Ethereum', 'Arbitrum')"
        },
        min_apy: %{
          type: :number,
          description: "Minimum APY percentage",
          default: 0.0
        },
        max_apr: %{
          type: :number,
          description: "Maximum APR percentage to exclude risky pools",
          default: 500.0
        },
        limit: %{
          type: :integer,
          description: "Maximum number of results",
          default: 20
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        opportunities: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              pool: %{type: :string},
              chain: %{type: :string},
              project: %{type: :string},
              apy: %{type: :number},
              tvlUsd: %{type: :number}
            }
          }
        },
        total_found: %{type: :integer}
      },
      required: ["opportunities", "total_found"]
    }

  alias Lux.Integrations.DeFiLlama

  require Logger

  @doc """
  Handler for the yield analytics prism.
  """
  def handler(input, _ctx) do
    chain = Map.get(input, "chain")
    min_apy = Map.get(input, "min_apy", 0.0)
    max_apr = Map.get(input, "max_apr", 500.0)
    limit = Map.get(input, "limit", 20)

    case DeFiLlama.yield_data() do
      {:ok, yields} when is_list(yields) ->
        filtered =
          yields
          |> Enum.filter(fn y ->
            apy = Map.get(y, "apy", 0)
            apy >= min_apy and apy <= max_apr
          end)
          |> Enum.filter(fn y ->
            case chain do
              nil -> true
              c -> Map.get(y, "chain", "") == c
            end
          end)
          |> Enum.sort_by(fn y -> Map.get(y, "apy", 0) end, :desc)
          |> Enum.take(limit)

        {:ok, %{
          opportunities: filtered,
          total_found: length(filtered),
          filters: %{chain: chain, min_apy: min_apy, max_apr: max_apr},
          analyzed_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }}

      {:error, err} ->
        Logger.error("Yield data fetch failed: #{inspect(err)}")
        {:error, "Failed to fetch yield data: #{inspect(err)}"}

      other ->
        Logger.error("Unexpected yield data format: #{inspect(other)}")
        {:error, "Unexpected yield data format"}
    end
  rescue
    e ->
      Logger.error("Yield analytics error: #{inspect(e)}")
      {:error, "Yield analysis failed: #{inspect(e)}"}
  end
end
