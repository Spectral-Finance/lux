defmodule Lux.Prisms.PancakeSwap.ApyOptimizerPrism do
  @moduledoc """
  Converts farming APRs to compounded APYs and finds the best compounding frequency.

  For an APR `r` (a fraction, `0.5` = 50%) compounded `n` times a year:

      apy = (1 + r / n) ^ n - 1

  Every compound costs gas, so for a position of `position_usd` the net APY is

      net_apy = apy - n * gas_cost_usd / position_usd

  The prism evaluates the candidate frequencies for each pool, picks the one with the
  highest net APY (the smaller frequency wins ties) and ranks the pools by that value.
  The pure function `apy/2` is exposed for reuse.

  ## Example

      iex> Lux.Prisms.PancakeSwap.ApyOptimizerPrism.run(%{
      ...>   pools: [%{id: "cake-bnb", apr: 0.4}, %{id: "usdt-busd", apr: 0.1}],
      ...>   position_usd: 10_000,
      ...>   gas_cost_usd: 0.5
      ...> })
      {:ok,
       %{
         best_pool: "cake-bnb",
         pools: [%{rank: 1, id: "cake-bnb", apr: 0.4, best_compounds_per_year: 365, ...}, ...]
       }}
  """

  use Lux.Prism,
    name: "PancakeSwap APY Optimizer",
    description: "Computes compounded APY, the best compounding frequency and ranks farm pools",
    input_schema: %{
      type: :object,
      properties: %{
        pools: %{
          type: :array,
          description: "Pools to compare",
          items: %{
            type: :object,
            properties: %{
              id: %{type: [:string, :integer], description: "Pool identifier"},
              apr: %{type: :number, minimum: 0, description: "APR as a fraction (0.25 = 25%)"},
              tvl_usd: %{type: :number, description: "Pool TVL in USD (passed through)"}
            },
            required: ["id", "apr"]
          }
        },
        position_usd: %{type: :number, description: "Position size in USD"},
        gas_cost_usd: %{
          type: :number,
          minimum: 0,
          description: "Gas cost of one compound in USD",
          default: 0
        },
        compounds_per_year: %{
          type: :integer,
          minimum: 1,
          description: "Frequency used for the reported `apy` (default 365)",
          default: 365
        },
        candidate_frequencies: %{
          type: :array,
          items: %{type: :integer, minimum: 1},
          description: "Compounds per year to evaluate"
        }
      },
      required: ["pools", "position_usd"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        best_pool: %{type: [:string, :integer]},
        position_usd: %{type: :number},
        pools: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              rank: %{type: :integer},
              id: %{type: [:string, :integer]},
              apr: %{type: :number},
              apy: %{type: :number},
              compounds_per_year: %{type: :integer},
              best_compounds_per_year: %{type: :integer},
              net_apy: %{type: :number}
            }
          }
        }
      },
      required: ["best_pool", "pools"]
    }

  alias Lux.Integrations.PancakeSwap

  @default_frequencies [1, 2, 4, 12, 24, 52, 104, 365, 730, 1460]

  @doc """
  Compound APY for an APR and `n` compounding periods per year.

  ## Examples

      iex> Lux.Prisms.PancakeSwap.ApyOptimizerPrism.apy(0.5, 1)
      0.5
  """
  @spec apy(number(), pos_integer()) :: float()
  def apy(apr, n) when is_number(apr) and apr >= 0 and is_integer(n) and n >= 1 do
    :math.pow(1 + apr / n, n) - 1
  end

  def handler(input, _ctx) do
    pools = PancakeSwap.field(input, :pools)
    position_usd = PancakeSwap.field(input, :position_usd)
    gas_cost = PancakeSwap.field(input, :gas_cost_usd, 0)
    per_year = PancakeSwap.field(input, :compounds_per_year, 365)

    with :ok <- validate_pools(pools),
         :ok <- validate_position(position_usd),
         :ok <- validate_gas(gas_cost),
         :ok <- validate_frequency(per_year),
         {:ok, candidates} <- candidates(PancakeSwap.field(input, :candidate_frequencies)) do
      ranked =
        pools
        |> Enum.map(&evaluate(&1, position_usd, gas_cost, per_year, candidates))
        |> Enum.sort_by(& &1.net_apy, :desc)
        |> Enum.with_index(1)
        |> Enum.map(fn {pool, rank} -> Map.put(pool, :rank, rank) end)

      {:ok, %{best_pool: hd(ranked).id, position_usd: position_usd, pools: ranked}}
    end
  end

  defp evaluate(pool, position_usd, gas_cost, per_year, candidates) do
    apr = PancakeSwap.field(pool, :apr) * 1.0
    best = Enum.max_by(candidates, &net_apy(apr, &1, gas_cost, position_usd))

    pool_result = %{
      id: PancakeSwap.field(pool, :id),
      apr: apr,
      apy: apy(apr, per_year),
      compounds_per_year: per_year,
      best_compounds_per_year: best,
      net_apy: net_apy(apr, best, gas_cost, position_usd)
    }

    case PancakeSwap.field(pool, :tvl_usd) do
      nil -> pool_result
      tvl -> Map.put(pool_result, :tvl_usd, tvl)
    end
  end

  defp net_apy(apr, n, gas_cost, position_usd), do: apy(apr, n) - n * gas_cost / position_usd

  defp validate_pools([_ | _] = pools) do
    if Enum.all?(pools, &valid_pool?/1),
      do: :ok,
      else: {:error, "each pool needs an id and a non-negative numeric apr"}
  end

  defp validate_pools(_), do: {:error, "pools must be a non-empty list"}

  defp valid_pool?(pool) when is_map(pool) do
    apr = PancakeSwap.field(pool, :apr)
    not is_nil(PancakeSwap.field(pool, :id)) and is_number(apr) and apr >= 0
  end

  defp valid_pool?(_), do: false

  defp validate_position(value) when is_number(value) and value > 0, do: :ok
  defp validate_position(_), do: {:error, "position_usd must be a positive number"}

  defp validate_gas(value) when is_number(value) and value >= 0, do: :ok
  defp validate_gas(_), do: {:error, "gas_cost_usd must be a non-negative number"}

  defp validate_frequency(value) when is_integer(value) and value >= 1, do: :ok
  defp validate_frequency(_), do: {:error, "compounds_per_year must be an integer >= 1"}

  defp candidates(nil), do: {:ok, @default_frequencies}

  defp candidates([_ | _] = list) do
    if Enum.all?(list, &(is_integer(&1) and &1 >= 1)),
      do: {:ok, list |> Enum.uniq() |> Enum.sort()},
      else: {:error, "candidate_frequencies must be integers >= 1"}
  end

  defp candidates(_), do: {:error, "candidate_frequencies must be a non-empty list"}
end
