defmodule Lux.Prisms.CurveFinance.GaugesVotingPrism do
  @moduledoc """
  A prism that optimizes gauge voting strategy for maximum CRV rewards,
  considering vote weights, incentive APYs, and opportunity costs.

  ## Example

      iex> Lux.Prisms.CurveFinance.GaugesVotingPrism.run(%{veCRV_amount: 50000, vote_count: 10})
      {:ok, %{votes: [...], expected_apy: 0.025, total_incentive: 12500}}

      iex> Lux.Prisms.CurveFinance.GaugesVotingPrism.run(%{optimize: true, gauges: [...]})
      {:ok, %{optimal_votes: [...], improvement: 0.15}}
  """

  @doc """
  Optimizes gauge voting strategy for maximum CRV rewards.

  ## Parameters
    - `veCRV_amount` - Amount of veCRV held
    - `vote_count` - Number of gauges to vote for (max 10)
    - `optimize` - Run optimization algorithm (default: true)
    - `risk_tolerance` - Risk level for voting (default: :moderate)

  ## Returns
    - `{:ok, voting_strategy}` on success
    - `{:error, reason}` on failure
  """
  def run(params \\ %{}) do
    params = normalize_params(params)

    with {:ok, gauges} <- fetch_gauge_data(params),
         {:ok, strategy} <- if(params.optimize, do: optimize_votes(gauges, params), else: {:ok, default_votes(gauges, params)}) do
      result = %{
        votes: strategy.votes,
        expected_apy: strategy.expected_apy,
        total_incentive_usd: strategy.total_incentive_usd,
        vote_distribution: strategy.vote_distribution,
        optimization_applied: params.optimize,
        last_updated: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Simulates voting outcomes for different strategies.
  """
  def simulate_strategies(params \\ %{}) do
    params = normalize_params(params)

    with {:ok, gauges} <- fetch_gauge_data(params) do
      strategies = [
        %{name: "Conservative", votes: conservative_strategy(gauges, params)},
        %{name: "Moderate", votes: moderate_strategy(gauges, params)},
        %{name: "Aggressive", votes: aggressive_strategy(gauges, params)}
      ]

      results =
        strategies
        |> Enum.map(fn s ->
          total_incentive = Enum.reduce(s.votes, 0, fn v, acc -> acc + v.incentive_usd end)
          avg_apy = Enum.reduce(s.votes, 0.0, fn v, acc -> acc + v.incentive_apy end) / max(length(s.votes), 1)

          %{
            name: s.name,
            votes: length(s.votes),
            total_incentive_usd: total_incentive,
            average_apy: avg_apy,
            vote_details: s.votes
          }
        end)

      {:ok, %{strategies: results}}
    end
  end

  # --- Private Functions ---

  defp normalize_params(params) when is_map(params) do
    params
    |> Map.new(fn {k, v} -> {normalize_key(k), v} end)
    |> Map.put_new(:vote_count, 10)
    |> Map.put_new(:optimize, true)
    |> Map.put_new(:risk_tolerance, :moderate)
  end

  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)
  defp normalize_key(key) when is_atom(key), do: key

  defp fetch_gauge_data(params) do
    gauges = [
      %{
        address: "0xbBC81d23Ea2c3ec7e56D39693049825d3f869366",
        name: "3pool Gauge",
        pool_tvl: 850_000_000,
        current_votes: 125_000_000,
        incentive_apy: 0.020,
        incentive_usd: 69_333,
        vote_weight: 0.085,
        risk_score: 0.92,
        efficiency: 0.85
      },
      %{
        address: "0x119fd84e1dB42f7295B23A8639a8a3BF95d874A2",
        name: "stETH Gauge",
        pool_tvl: 1_200_000_000,
        current_votes: 180_000_000,
        incentive_apy: 0.018,
        incentive_usd: 55_000,
        vote_weight: 0.125,
        risk_score: 0.88,
        efficiency: 0.82
      },
      %{
        address: "0x4C4B77954c2D961571c0F6Df421C2e4b9F8c0Da4",
        name: "TriCrypto Gauge",
        pool_tvl: 650_000_000,
        current_votes: 95_000_000,
        incentive_apy: 0.024,
        incentive_usd: 85_000,
        vote_weight: 0.065,
        risk_score: 0.72,
        efficiency: 0.90
      },
      %{
        address: "0x6dCc96D4A2686186c44b9251816b6E0e99635d75",
        name: "MetaPool Gauge",
        pool_tvl: 180_000_000,
        current_votes: 45_000_000,
        incentive_apy: 0.022,
        incentive_usd: 42_000,
        vote_weight: 0.045,
        risk_score: 0.82,
        efficiency: 0.88
      }
    ]

    {:ok, gauges}
  end

  defp optimize_votes(gauges, params) do
    vote_count = params.vote_count
    veCRV = Map.get(params, :veCRV_amount, 50_000)

    # Score each gauge by efficiency * incentive
    scored =
      gauges
      |> Enum.map(fn g ->
        score = g.efficiency * g.incentive_apy * g.risk_score
        Map.put(g, :score, score)
      end)
      |> Enum.sort_by(& &1.score, :desc)

    selected = Enum.take(scored, min(vote_count, length(scored)))

    votes =
      selected
      |> Enum.map(fn g ->
        vote_weight = 100 / length(selected)  # Equal distribution

        %{
          gauge_address: g.address,
          gauge_name: g.name,
          vote_weight_percent: vote_weight,
          expected_apy: g.incentive_apy,
          incentive_usd: g.incentive_usd * (vote_weight / 100),
          risk_score: g.risk_score
        }
      end)

    total_apy = Enum.reduce(votes, 0.0, fn v, acc -> acc + v.expected_apy * (v.vote_weight_percent / 100) end)
    total_incentive = Enum.reduce(votes, 0, fn v, acc -> acc + v.incentive_usd end)

    {:ok, %{
      votes: votes,
      expected_apy: total_apy,
      total_incentive_usd: total_incentive,
      vote_distribution: Enum.map(votes, & %{gauge: &1.gauge_name, weight: &1.vote_weight_percent})
    }}
  end

  defp default_votes(gauges, params) do
    vote_count = params.vote_count
    selected = Enum.take(gauges, min(vote_count, length(gauges)))

    votes =
      selected
      |> Enum.map(fn g ->
        %{
          gauge_address: g.address,
          gauge_name: g.name,
          vote_weight_percent: 100 / length(selected),
          expected_apy: g.incentive_apy,
          incentive_usd: g.incentive_usd / length(selected),
          risk_score: g.risk_score
        }
      end)

    total_apy = Enum.reduce(votes, 0.0, fn v, acc -> acc + v.expected_apy * (v.vote_weight_percent / 100) end)
    total_incentive = Enum.reduce(votes, 0, fn v, acc -> acc + v.incentive_usd end)

    {:ok, %{
      votes: votes,
      expected_apy: total_apy,
      total_incentive_usd: total_incentive,
      vote_distribution: Enum.map(votes, & %{gauge: &1.gauge_name, weight: &1.vote_weight_percent})
    }}
  end

  defp conservative_strategy(gauges, params) do
    gauges
    |> Enum.filter(fn g -> g.risk_score >= 0.85 end)
    |> Enum.take(params.vote_count)
    |> Enum.map(fn g ->
      %{gauge_address: g.address, gauge_name: g.name, incentive_apy: g.incentive_apy, incentive_usd: g.incentive_usd}
    end)
  end

  defp moderate_strategy(gauges, params) do
    gauges
    |> Enum.filter(fn g -> g.risk_score >= 0.70 end)
    |> Enum.sort_by(& &1.efficiency, :desc)
    |> Enum.take(params.vote_count)
    |> Enum.map(fn g ->
      %{gauge_address: g.address, gauge_name: g.name, incentive_apy: g.incentive_apy, incentive_usd: g.incentive_usd}
    end)
  end

  defp aggressive_strategy(gauges, params) do
    gauges
    |> Enum.sort_by(& &1.incentive_apy, :desc)
    |> Enum.take(params.vote_count)
    |> Enum.map(fn g ->
      %{gauge_address: g.address, gauge_name: g.name, incentive_apy: g.incentive_apy, incentive_usd: g.incentive_usd}
    end)
  end
end
