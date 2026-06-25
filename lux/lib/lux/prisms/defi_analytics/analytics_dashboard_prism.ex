defmodule Lux.Prisms.DefiAnalytics.AnalyticsDashboard do
  @moduledoc """
  A prism that generates a comprehensive DeFi analytics dashboard
  by aggregating data from DeFiLlama and Dune Analytics.

  Collects TVL, yield, volume, and protocol metrics into a unified view.

  ## Example

      iex> Lux.Prisms.DefiAnalytics.AnalyticsDashboard.run(%{
      ...>   protocols: ["uniswap", "aave", "lido"],
      ...>   include_chains: true,
      ...>   include_yield: true
      ...> })
      {:ok, %{dashboard: %{...}}}
  """

  use Lux.Prism,
    name: "DeFi Analytics Dashboard",
    description: "Generates a comprehensive DeFi analytics dashboard from DeFiLlama and Dune data",
    input_schema: %{
      type: :object,
      properties: %{
        protocols: %{
          type: :array,
          items: %{type: :string},
          description: "List of protocol slugs to include (e.g., ['uniswap', 'aave'])"
        },
        include_chains: %{
          type: :boolean,
          description: "Include chain-level TVL breakdown",
          default: false
        },
        include_yield: %{
          type: :boolean,
          description: "Include yield farming data",
          default: false
        },
        include_volume: %{
          type: :boolean,
          description: "Include volume analytics",
          default: false
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        dashboard: %{
          type: :object,
          properties: %{
            total_tvl: %{type: :number},
            protocols: %{type: :array},
            chains: %{type: :array},
            yield_pools: %{type: :array},
            volumes: %{type: :object},
            generated_at: %{type: :string}
          }
        }
      },
      required: ["dashboard"]
    }

  alias Lux.Integrations.DeFiLlama

  require Logger

  @doc """
  Handler for the analytics dashboard prism.
  """
  def handler(input, _ctx) do
    protocols = Map.get(input, "protocols", [])
    include_chains = Map.get(input, "include_chains", false)
    include_yield = Map.get(input, "include_yield", false)
    include_volume = Map.get(input, "include_volume", false)

    tasks = [
      {:total_tvl, Task.async(fn -> DeFiLlama.total_tvl() end)},
      {:protocols, Task.async(fn -> DeFiLlama.protocols() end)}
    ]

    tasks =
      if include_chains do
        [{:chains, Task.async(fn -> DeFiLlama.chains() end)} | tasks]
      else
        tasks
      end

    tasks =
      if include_yield do
        [{:yield, Task.async(fn -> DeFiLlama.yield_data() end)} | tasks]
      else
        tasks
      end

    volume_tasks =
      if include_volume and protocols != [] do
        Enum.map(protocols, fn p ->
          {p, Task.async(fn -> DeFiLlama.volume(p) end)}
        end)
      else
        []
      end

    protocol_tasks =
      Enum.map(protocols, fn p ->
        {p, Task.async(fn -> DeFiLlama.protocol_tvl(p) end)}
      end)

    all_tasks = tasks ++ volume_tasks ++ protocol_tasks

    results =
      Enum.reduce(all_tasks, %{total_tvl: nil, protocols: nil, chains: nil, yield: nil, volumes: %{}, protocols_detail: %{}}, fn
        {key, task}, acc ->
          case Task.await(task, 30_000) do
            {:ok, data} -> Map.put(acc, key, data)
            {:error, err} ->
              Logger.warning("DeFiLlama task #{key} failed: #{inspect(err)}")
              acc
            error ->
              Logger.warning("DeFiLlama task #{key} unexpected: #{inspect(error)}")
              acc
          end
      end)

    dashboard = %{
      total_tvl: results[:total_tvl],
      all_protocols: results[:protocols],
      chain_breakdown: results[:chains],
      top_protocols: results[:protocols_detail],
      yield_pools: results[:yield],
      volume_data: results[:volumes],
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    {:ok, %{dashboard: dashboard}}
  rescue
    e ->
      Logger.error("Analytics dashboard error: #{inspect(e)}")
      {:error, "Failed to generate dashboard: #{inspect(e)}"}
  end
end
