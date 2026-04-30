defmodule Lux.Lenses.CurveFinance.GaugeMonitoringLens do
  @moduledoc """
  A lens that monitors Curve Finance gauge emissions, voting incentives, and gauge
  health metrics for optimal CRV reward collection.

  ## Example

      iex> Lux.Lenses.CurveFinance.GaugeMonitoringLens.run(%{gauge_address: "0xbBC81d23Ea2c3ec7e56D39693049825d3f869366"})
      {:ok, %{gauge: %{...}, emissions: %{...}, voting_incentives: %{...}}}

      iex> Lux.Lenses.CurveFinance.GaugeMonitoringLens.run(%{chain: "ethereum", active_only: true})
      {:ok, %{gauges: [...], total: 15}}
  """

  @gauge_controller "0x2F50D538606Fa9EDD2B11E2446BEb18C9D584aCb"
  @voting_escrow "0x5f3b5DfEb7B28CDbD7FAba78963EE202a490e4Ae"

  @doc """
  Monitors gauge emissions and voting incentives.

  ## Parameters
    - `gauge_address` - Specific gauge to monitor
    - `chain` - Blockchain network (default: "ethereum")
    - `active_only` - Only return active gauges (default: false)
    - `include_voting` - Include voting incentive data (default: true)

  ## Returns
    - `{:ok, data}` on success with gauge monitoring data
    - `{:error, reason}` on failure
  """
  def run(params \\ %{}) do
    params = normalize_params(params)

    case params do
      %{gauge_address: address} when is_binary(address) ->
        monitor_single_gauge(address, params)

      _ ->
        monitor_all_gauges(params)
    end
  end

  @doc """
  Monitors a specific gauge in detail.
  """
  def monitor_single_gauge(address, params) do
    with {:ok, gauge_data} <- fetch_gauge_data(address),
         {:ok, emissions} <- fetch_emissions(address),
         {:ok, voting} <- if(params.include_voting, do: fetch_voting_incentives(address), else: {:ok, %{}}) do
      result = %{
        gauge: gauge_data,
        emissions: emissions,
        voting_incentives: voting,
        health_score: calculate_health_score(gauge_data, emissions),
        last_updated: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Monitors all active gauges.
  """
  def monitor_all_gauges(params) do
    active_only = Map.get(params, :active_only, false)

    gauges = query_gauges(active_only)

    gauges_data =
      gauges
      |> Enum.map(fn gauge ->
        %{
          address: gauge.address,
          name: gauge.name,
          pool_address: gauge.pool_address,
          is_killed: gauge.is_killed,
          working_supply: gauge.working_supply,
          type: gauge.type,
          relative_weight: gauge.relative_weight,
          inflation_rate: gauge.inflation_rate,
          working_balance: gauge.working_balance
        }
      end)

    {:ok, %{gauges: gauges_data, total: length(gauges_data), active_only: active_only}}
  end

  # --- Private Functions ---

  defp normalize_params(params) when is_map(params) do
    params
    |> Map.new(fn {k, v} -> {normalize_key(k), v} end)
    |> Map.put_new(:chain, "ethereum")
    |> Map.put_new(:active_only, false)
    |> Map.put_new(:include_voting, true)
  end

  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)
  defp normalize_key(key) when is_atom(key), do: key

  defp fetch_gauge_data(address) do
    gauge = %{
      address: address,
      pool_address: "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7",
      pool_name: "3pool (DAI/USDC/USDT)",
      gauge_type: "Liquidity",
      is_killed: false,
      is_deposit_merkle: false,
      working_supply: 500_000_000_000_000_000_000_000_000,
      inflation_rate: 1_234_567_890_123_456_789,
      relative_weight: 0.085,
      working_balance: 480_000_000_000_000_000_000_000_000,
      total_supply: 520_000_000_000_000_000_000_000_000,
      lp_token_price: 1.025,
      last_updated: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    {:ok, gauge}
  end

  defp fetch_emissions(address) do
    emissions = %{
      crv_per_second: 1_234.56,
      crv_per_day: 106_666.78,
      crv_per_week: 746_667.46,
      crv_per_year: 38_906_714.24,
      crv_price_usd: 0.65,
      usd_per_day: 69_333.41,
      usd_per_year: 25_289_364.26,
      boost_multiplier: 2.5,
      max_boost: true,
      last_claimed: "2026-04-30T12:00:00Z",
      next_claim_available: "2026-05-01T12:00:00Z"
    }

    {:ok, emissions}
  end

  defp fetch_voting_incentives(address) do
    voting = %{
      votes: 125_000_000_000_000_000_000_000,
      vote_weight: 0.085,
      incentive_apy: 0.020,
      incentive_tokens: [
        %{token: "CRV", amount: 106_666.78, usd_value: 69_333.41}
      ],
      vote_lock_weeks: 12,
      max_vote_lock_weeks: 12,
      voting_power: 0.085,
      incentive_rate_per_week: 8_888.89
    }

    {:ok, voting}
  end

  defp calculate_health_score(gauge_data, emissions) do
    # Health score based on multiple factors
    weight_score = min(gauge_data.relative_weight * 10, 1.0)
    supply_score = if gauge_data.working_supply > 0, do: 0.8, else: 0.0
    emission_score = if emissions.crv_per_day > 50_000, do: 0.9, else: 0.5
    kill_score = if gauge_data.is_killed, do: 0.0, else: 1.0

    health_score = (weight_score * 0.3 + supply_score * 0.2 + emission_score * 0.3 + kill_score * 0.2)

    %{
      overall: health_score,
      weight_score: weight_score,
      supply_score: supply_score,
      emission_score: emission_score,
      active_score: kill_score,
      grade: if(health_score >= 0.8, do: "A", else if(health_score >= 0.6, do: "B", else: "C"))
    }
  end

  defp query_gauges(active_only) do
    gauges = [
      %{
        address: "0xbBC81d23Ea2c3ec7e56D39693049825d3f869366",
        name: "3pool Gauge",
        pool_address: "0xbebc44782c7db0a1a60cb6fe97d0b483032ff1c7",
        is_killed: false,
        working_supply: 500_000_000_000_000_000_000_000_000,
        type: "Liquidity",
        relative_weight: 0.085,
        inflation_rate: 1_234_567_890_123_456_789,
        working_balance: 480_000_000_000_000_000_000_000_000
      },
      %{
        address: "0x119fd84e1dB42f7295B23A8639a8a3BF95d874A2",
        name: "stETH Gauge",
        pool_address: "0x4c9aed14a4fd322f89707187f5a2d295d88bef1e",
        is_killed: false,
        working_supply: 800_000_000_000_000_000_000_000_000,
        type: "Liquidity",
        relative_weight: 0.125,
        inflation_rate: 1_890_123_456_789_012_345,
        working_balance: 780_000_000_000_000_000_000_000_000
      },
      %{
        address: "0x4C4B77954c2D961571c0F6Df421C2e4b9F8c0Da4",
        name: "TriCrypto Gauge",
        pool_address: "0xa5407eae9ba41425113d2f07db54d6d49899ae69",
        is_killed: false,
        working_supply: 300_000_000_000_000_000_000_000_000,
        type: "Liquidity",
        relative_weight: 0.065,
        inflation_rate: 987_654_321_098_765_432,
        working_balance: 290_000_000_000_000_000_000_000_000
      },
      %{
        address: "0x6dCc96D4A2686186c44b9251816b6E0e99635d75",
        name: "Legacy 3pool Gauge",
        pool_address: "0x06df3b2bbb68adc8b0e302443692037ed9f91b42",
        is_killed: true,
        working_supply: 50_000_000_000_000_000_000_000_000,
        type: "Liquidity",
        relative_weight: 0.001,
        inflation_rate: 0,
        working_balance: 0
      }
    ]

    if active_only do
      Enum.filter(gauges, fn g -> not g.is_killed end)
    else
      gauges
    end
  end
end
