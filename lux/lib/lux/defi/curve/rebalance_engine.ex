defmodule Lux.Defi.Curve.RebalanceEngine do
  @moduledoc """
  Automated rebalancing and imbalance arbitrage engine for Curve stablecoin pools:
  - Exploits pool imbalances for positive slippage bonuses
  - Directs deposits to the scarcest under-represented coin
  - Evaluates depeg risk vs yield bonus
  """

  alias Lux.Defi.Curve.PoolManager

  @doc """
  Evaluates pool balance skew and recommends optimal single-coin deposit strategy.
  """
  @spec evaluate_imbalance(list(number()), float()) :: %{
          imbalanced?: boolean(),
          preferred_deposit_coin_index: non_neg_integer(),
          recommended_action: :deposit_scarce | :balanced_deposit | :caution_depeg,
          bonus_estimated_pct: float()
        }
  def evaluate_imbalance(balances, threshold_pct \\ 0.05) when is_list(balances) do
    analysis = PoolManager.analyze_balances(balances, threshold_pct)

    cond do
      analysis.max_deviation_pct >= 25.0 ->
        # Severe depeg risk (e.g. UST or abnormal skew), caution recommended
        %{
          imbalanced?: true,
          preferred_deposit_coin_index: analysis.underrepresented_index,
          recommended_action: :caution_depeg,
          bonus_estimated_pct: 0.0
        }

      analysis.imbalanced? ->
        # Healthy pool with actionable imbalance: depositing scarce coin yields bonus LP tokens
        bonus_pct = Float.round(min(analysis.max_deviation_pct * 0.02, 0.5), 3)

        %{
          imbalanced?: true,
          preferred_deposit_coin_index: analysis.underrepresented_index,
          recommended_action: :deposit_scarce,
          bonus_estimated_pct: bonus_pct
        }

      true ->
        %{
          imbalanced?: false,
          preferred_deposit_coin_index: 0,
          recommended_action: :balanced_deposit,
          bonus_estimated_pct: 0.0
        }
    end
  end
end
