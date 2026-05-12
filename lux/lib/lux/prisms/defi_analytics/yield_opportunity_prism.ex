defmodule Lux.Prisms.DeFiAnalytics.YieldOpportunityPrism do
  @moduledoc """
  A prism that finds the best yield opportunities from DeFiLlama yield pools.

  Takes a minimum APY filter and returns the top pools sorted by APY,
  with additional filtering options for chain, project, and stablecoin status.

  ## Examples

      iex> Lux.Prisms.DeFiAnalytics.YieldOpportunityPrism.run(%{
      ...>   min_apy: 10.0,
      ...>   limit: 5,
      ...>   chain: "Ethereum"
      ...> })
      {:ok, %{
        opportunities: [
          %{pool: "0x...", apy: 25.5, tvl_usd: 5000000.0, chain: "Ethereum", project: "Lido", symbol: "stETH"},
          ...
        ],
        total_pools_filtered: 5,
        min_apy_filter: 10.0
      }}
  """

  use Lux.Prism,
    name: "Yield Opportunity Finder",
    description: "Finds the best yield opportunities from DeFiLlama with configurable APY and TVL filters",
    input_schema: %{
      type: :object,
      properties: %{
        min_apy: %{
          type: :number,
          description: "Minimum APY percentage to filter pools (default: 0.0)",
          default: 0.0
        },
        max_apy: %{
          type: :number,
          description: "Maximum APY percentage to filter pools (optional)"
        },
        min_tvl_usd: %{
          type: :number,
          description: "Minimum TVL in USD to filter pools (optional)",
          default: 0.0
        },
        chain: %{
          type: :string,
          description: "Filter by blockchain chain (e.g. 'Ethereum', 'Polygon', 'Arbitrum')"
        },
        project: %{
          type: :string,
          description: "Filter by project name (e.g. 'Aave', 'Compound', 'Lido')"
        },
        stablecoin: %{
          type: :boolean,
          description: "Filter to only stablecoin pools"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of pools to return (default: 10)",
          default: 10
        }
      },
      required: []
    },
    output_schema: %{
      type: :object,
      properties: %{
        opportunities: %{
          type: :array,
          description: "Top yield opportunities sorted by APY descending",
          items: %{
            type: :object,
            properties: %{
              pool: %{type: :string},
              apy: %{type: :number},
              tvl_usd: %{type: :number},
              chain: %{type: :string},
              project: %{type: :string},
              symbol: %{type: :string},
              pool_meta: %{type: :string},
              il_risk: %{type: :string},
              stablecoin: %{type: :boolean}
            }
          }
        },
        total_pools_filtered: %{type: :integer, description: "Number of pools matching the filters"},
        min_apy_filter: %{type: :number, description: "The minimum APY used for filtering"}
      },
      required: ["opportunities", "total_pools_filtered", "min_apy_filter"]
    }

  alias Lux.Lenses.DeFiLlama.YieldsLens

  @impl true
  def handler(input, _ctx) do
    min_apy = Map.get(input, :min_apy, 0.0)
    max_apy = Map.get(input, :max_apy)
    min_tvl = Map.get(input, :min_tvl_usd, 0.0)
    chain_filter = Map.get(input, :chain)
    project_filter = Map.get(input, :project)
    stablecoin_filter = Map.get(input, :stablecoin)
    limit = Map.get(input, :limit, 10)

    case YieldsLens.focus(%{}) do
      {:ok, %{pools: pools}} ->
        filtered =
          pools
          |> Enum.filter(fn p -> (p.apy || 0.0) >= min_apy end)
          |> then(fn ps ->
            case max_apy do
              nil -> ps
              max -> Enum.filter(ps, fn p -> (p.apy || 0.0) <= max end)
            end
          end)
          |> Enum.filter(fn p -> (p.tvl_usd || 0.0) >= min_tvl end)
          |> then(fn ps ->
            case chain_filter do
              nil -> ps
              chain -> Enum.filter(ps, fn p -> String.downcase(p.chain || "") == String.downcase(chain) end)
            end
          end)
          |> then(fn ps ->
            case project_filter do
              nil -> ps
              project -> Enum.filter(ps, fn p -> String.downcase(p.project || "") == String.downcase(project) end)
            end
          end)
          |> then(fn ps ->
            case stablecoin_filter do
              nil -> ps
              true -> Enum.filter(ps, fn p -> p.stablecoin == true end)
              false -> Enum.filter(ps, fn p -> p.stablecoin == false end)
            end
          end)
          |> Enum.sort_by(fn p -> -(p.apy || 0.0) end)
          |> Enum.take(limit)

        opportunities =
          Enum.map(filtered, fn p ->
            %{
              pool: p.pool,
              apy: p.apy,
              tvl_usd: p.tvl_usd,
              chain: p.chain,
              project: p.project,
              symbol: p.symbol,
              pool_meta: p.pool_meta,
              il_risk: p.il_risk,
              stablecoin: p.stablecoin
            }
          end)

        {:ok, %{opportunities: opportunities, total_pools_filtered: length(opportunities), min_apy_filter: min_apy}}

      {:error, reason} ->
        {:error, "Failed to fetch yield pools: #{inspect(reason)}"}
    end
  end
end
