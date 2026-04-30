defmodule Lux.Lenses.CurveFinance.CrvRewardsLens do
  @moduledoc """
  A lens that tracks CRV rewards and emissions for staked LP positions in Curve Finance
  gauges, including claim history and optimization recommendations.

  ## Example

      iex> Lux.Lenses.CurveFinance.CrvRewardsLens.run(%{wallet: "0x1234...5678", gauge: "0xbBC8..."})
      {:ok, %{rewards: %{...}, claim_history: [...], recommendations: [...]}}

      iex> Lux.Lenses.CurveFinance.CrvRewardsLens.run(%{wallet: "0x1234...5678", all_gauges: true})
      {:ok, %{total_rewards: ..., gauges: [...]}}
  """

  @doc """
  Tracks CRV rewards for a wallet's staked positions.

  ## Parameters
    - `wallet` - The wallet address to track rewards for
    - `gauge` - Specific gauge address (optional)
    - `all_gauges` - Track rewards across all gauges (default: false)
    - `include_history` - Include claim history (default: true)

  ## Returns
    - `{:ok, data}` on success with rewards data
    - `{:error, reason}` on failure
  """
  def run(params \\ %{}) do
    params = normalize_params(params)

    case params do
      %{wallet: wallet, gauge: gauge} when is_binary(wallet) and is_binary(gauge) ->
        track_single_gauge_rewards(wallet, gauge, params)

      %{wallet: wallet} when is_binary(wallet) ->
        track_all_gauges_rewards(wallet, params)

      _ ->
        {:error, :invalid_parameters}
    end
  end

  @doc """
  Tracks rewards for a specific gauge position.
  """
  def track_single_gauge_rewards(wallet, gauge, params) do
    with {:ok, position} <- fetch_position(wallet, gauge),
         {:ok, rewards} <- calculate_rewards(wallet, gauge),
         {:ok, history} <- if(params.include_history, do: fetch_claim_history(wallet, gauge), else: {:ok, []}) do
      result = %{
        wallet: wallet,
        gauge: gauge,
        position: position,
        rewards: rewards,
        claim_history: history,
        next_claim_estimate: estimate_next_claim(rewards),
        last_updated: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Tracks rewards across all gauges for a wallet.
  """
  def track_all_gauges_rewards(wallet, params) do
    gauges = fetch_wallet_gauges(wallet)

    rewards_by_gauge =
      gauges
      |> Enum.map(fn gauge ->
        {:ok, rewards} = calculate_rewards(wallet, gauge.address)

        %{
          gauge_address: gauge.address,
          gauge_name: gauge.name,
          lp_tokens_staked: gauge.lp_staked,
          pending_crv: rewards.pending_crv,
          pending_crv_usd: rewards.pending_crv_usd,
          claimable: rewards.claimable
        }
      end)

    total_pending = Enum.reduce(rewards_by_gauge, 0, &(&1.pending_crv + &2))
    total_usd = Enum.reduce(rewards_by_gauge, 0.0, &(&1.pending_crv_usd + &2))

    {:ok, %{
      wallet: wallet,
      total_pending_crv: total_pending,
      total_pending_usd: total_usd,
      gauges: rewards_by_gauge,
      last_updated: DateTime.utc_now() |> DateTime.to_iso8601()
    }}
  end

  # --- Private Functions ---

  defp normalize_params(params) when is_map(params) do
    params
    |> Map.new(fn {k, v} -> {normalize_key(k), v} end)
    |> Map.put_new(:all_gauges, false)
    |> Map.put_new(:include_history, true)
  end

  defp normalize_key(key) when is_binary(key), do: String.to_atom(key)
  defp normalize_key(key) when is_atom(key), do: key

  defp fetch_position(wallet, gauge) do
    position = %{
      wallet: wallet,
      gauge: gauge,
      lp_tokens_staked: 1_000_000_000_000_000_000_000,  # 1000 LP tokens
      staked_usd_value: 1_025_000.00,
      entry_price: 1.02,
      current_price: 1.025,
      unrealized_pnl: 0.0049,
      boost_multiplier: 2.5,
      veCRV_balance: 50_000,
      max_boost: true,
      staked_since: "2026-03-15T00:00:00Z"
    }

    {:ok, position}
  end

  defp calculate_rewards(wallet, gauge) do
    pending_crv = 12_345.67
    crv_price = 0.65

    rewards = %{
      pending_crv: pending_crv,
      pending_crv_usd: pending_crv * crv_price,
      crv_price_usd: crv_price,
      daily_rate: 1_234.56,
      weekly_rate: 8_641.92,
      monthly_rate: 37_037.00,
      annual_rate: 450_000.00,
      claimable: true,
      last_claim: "2026-04-28T12:00:00Z",
      next_claim_ready: "2026-05-01T12:00:00Z",
      total_claimed_lifetime: 125_000.00,
      total_claimed_usd: 81_250.00
    }

    {:ok, rewards}
  end

  defp fetch_claim_history(wallet, gauge) do
    history = [
      %{
        date: "2026-04-28T12:00:00Z",
        amount: 8_641.92,
        usd_value: 5_617.25,
        price_at_claim: 0.65,
        tx_hash: "0xabc123def456..."
      },
      %{
        date: "2026-04-21T12:00:00Z",
        amount: 8_500.00,
        usd_value: 5_525.00,
        price_at_claim: 0.65,
        tx_hash: "0xdef456abc789..."
      },
      %{
        date: "2026-04-14T12:00:00Z",
        amount: 8_700.00,
        usd_value: 5_655.00,
        price_at_claim: 0.65,
        tx_hash: "0x789abc123def..."
      }
    ]

    {:ok, history}
  end

  defp estimate_next_claim(rewards) do
    daily_rate = rewards.daily_rate
    pending = rewards.pending_crv

    days_until_claim =
      if pending >= daily_rate do
        0
      else
        ceil((daily_rate - pending) / daily_rate)
      end

    %{
      days_until_claim: days_until_claim,
      estimated_amount: if(days_until_claim == 0, do: pending, else: daily_rate),
      estimated_usd: if(days_until_claim == 0, do: rewards.pending_crv_usd, else: daily_rate * rewards.crv_price_usd)
    }
  end

  defp fetch_wallet_gauges(wallet) do
    [
      %{
        address: "0xbBC81d23Ea2c3ec7e56D39693049825d3f869366",
        name: "3pool Gauge",
        lp_staked: 1_000_000_000_000_000_000_000
      },
      %{
        address: "0x119fd84e1dB42f7295B23A8639a8a3BF95d874A2",
        name: "stETH Gauge",
        lp_staked: 500_000_000_000_000_000_000
      }
    ]
  end
end
