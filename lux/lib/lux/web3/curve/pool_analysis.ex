defmodule Lux.Web3.Curve.PoolAnalysis do
  @moduledoc """
  Analysis, scoring and selection of Curve Finance stablecoin pools.

  The analysis is intentionally pure and integer based so the same input always
  produces the same result, which makes pool selection deterministic and safe to
  run inside automated rebalancing loops.

  A *pool snapshot* is a plain map with the following keys:

    * `:address` - pool contract address (used for tie-breaking, optional)
    * `:balances` - non-empty list of non-negative integer coin reserves
    * `:virtual_price` - LP token virtual price (uint256, `1.0` is `1e18`)
    * `:fee` - pool fee expressed with `1e10` precision (Curve's native fee unit)
    * `:crv_reward_rate` - optional CRV emission rate (uint256, `1e18` == 100%)

  The produced analysis contains a `:score` between `0` and `30_000` where higher
  is better, and a `:recommendation` of `:provide_liquidity`, `:hold` or
  `:rebalance`.
  """

  @bps 10_000
  # Curve fees use 1e10 precision (i.e. `fee` of 4_000_000 == 0.04%).
  @max_fee 10_000_000_000
  # A `crv_reward_rate` of `1e18` is treated as a 100% reward contribution.
  @reward_scale 100_000_000_000_000
  @provide_threshold @bps * 2
  @hold_threshold @bps

  @type pool :: map()
  @type analysis :: %{
          address: term(),
          total_liquidity: non_neg_integer(),
          virtual_price: pos_integer(),
          imbalance_bps: non_neg_integer(),
          fee_bps: non_neg_integer(),
          reward_bps: non_neg_integer(),
          score: integer(),
          recommendation: :provide_liquidity | :hold | :rebalance
        }

  @doc """
  Analyses a single pool snapshot.

  Returns `{:ok, analysis}` or a typed `{:error, reason}`.
  """
  @spec analyze(term()) :: {:ok, analysis()} | {:error, atom()}
  def analyze(pool) when is_map(pool) do
    with {:ok, balances} <- fetch_balances(pool),
         {:ok, virtual_price} <- fetch_virtual_price(pool),
         {:ok, fee} <- fetch_fee(pool),
         {:ok, reward_rate} <- fetch_reward_rate(pool) do
      imbalance = imbalance_bps(balances)
      fee_bps = div(fee, 1_000_000)
      reward_bps = min(div(reward_rate, @reward_scale), @bps)
      score = @bps - imbalance + (@bps - fee_bps) + reward_bps

      {:ok,
       %{
         address: Map.get(pool, :address),
         total_liquidity: Enum.sum(balances),
         virtual_price: virtual_price,
         imbalance_bps: imbalance,
         fee_bps: fee_bps,
         reward_bps: reward_bps,
         score: score,
         recommendation: recommendation(score)
       }}
    end
  end

  def analyze(_pool), do: {:error, :invalid_pool}

  @doc """
  Analyses and ranks a list of pools from best to worst score.

  Returns `{:ok, [analysis]}` or a typed `{:error, reason}`. An empty list is
  rejected with `{:error, :no_pools}` and any invalid pool rejects the whole
  batch so callers never act on partially analysed data.
  """
  @spec rank(term()) :: {:ok, [analysis()]} | {:error, atom()}
  def rank([]), do: {:error, :no_pools}

  def rank(pools) when is_list(pools) do
    results = Enum.map(pools, &analyze/1)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        ranked =
          results
          |> Enum.map(fn {:ok, analysis} -> analysis end)
          |> Enum.sort_by(fn analysis -> {-analysis.score, analysis.address || ""} end)

        {:ok, ranked}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def rank(_pools), do: {:error, :invalid_pools}

  @doc """
  Selects the single best pool from a list, or a typed error when none qualify.
  """
  @spec select_best(term()) :: {:ok, analysis()} | {:error, atom()}
  def select_best([]), do: {:error, :no_pools}

  def select_best(pools) when is_list(pools) do
    with {:ok, [best | _]} <- rank(pools) do
      {:ok, best}
    end
  end

  def select_best(_pools), do: {:error, :invalid_pools}

  defp fetch_balances(%{balances: balances}) when is_list(balances) and balances != [] do
    cond do
      not Enum.all?(balances, &(is_integer(&1) and &1 >= 0)) -> {:error, :invalid_balance}
      Enum.sum(balances) == 0 -> {:error, :empty_liquidity}
      true -> {:ok, balances}
    end
  end

  defp fetch_balances(%{balances: []}), do: {:error, :empty_balances}
  defp fetch_balances(_pool), do: {:error, :missing_balances}

  defp fetch_virtual_price(%{virtual_price: price}) when is_integer(price) and price > 0,
    do: {:ok, price}

  defp fetch_virtual_price(_pool), do: {:error, :invalid_virtual_price}

  defp fetch_fee(%{fee: fee}) when is_integer(fee) and fee >= 0 and fee <= @max_fee,
    do: {:ok, fee}

  defp fetch_fee(_pool), do: {:error, :invalid_fee}

  defp fetch_reward_rate(%{crv_reward_rate: rate}) when is_integer(rate) and rate >= 0,
    do: {:ok, rate}

  defp fetch_reward_rate(%{crv_reward_rate: _rate}), do: {:error, :invalid_reward_rate}
  defp fetch_reward_rate(_pool), do: {:ok, 0}

  # `(max - min) * count * bps / total` is the exact integer form of
  # `(max - min) / mean * bps`.
  defp imbalance_bps(balances) do
    total = Enum.sum(balances)
    div((Enum.max(balances) - Enum.min(balances)) * length(balances) * @bps, total)
  end

  defp recommendation(score) when score >= @provide_threshold, do: :provide_liquidity
  defp recommendation(score) when score >= @hold_threshold, do: :hold
  defp recommendation(_score), do: :rebalance
end
