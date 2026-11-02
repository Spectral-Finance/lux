defmodule Lux.Trading.Hyperliquid.MarginController do
  @moduledoc """
  Margin and leverage controller for Hyperliquid trading accounts:
  - Initial and Maintenance Margin (IM / MM) evaluation
  - Account equity and free collateral tracking
  - Margin ratio and liquidation danger buffer
  - Cross vs Isolated margin mode switching
  - Dynamic leverage limit enforcement
  """

  @coin_max_leverage %{
    "BTC" => 50,
    "ETH" => 50,
    "SOL" => 20,
    "AVAX" => 20,
    "ARB" => 20,
    "DEFAULT" => 10
  }

  @doc """
  Returns the maximum allowable leverage for a specific coin.
  """
  @spec max_leverage_for(String.t()) :: pos_integer()
  def max_leverage_for(coin) when is_binary(coin) do
    Map.get(@coin_max_leverage, String.upcase(coin), @coin_max_leverage["DEFAULT"])
  end

  @doc """
  Evaluates account margin state given balance, open positions, and maintenance margin rates.
  """
  @spec evaluate_account_margin(float(), list(map())) :: %{
          account_equity: float(),
          total_notional: float(),
          initial_margin_used: float(),
          maintenance_margin_required: float(),
          free_collateral: float(),
          margin_ratio: float(),
          margin_call?: boolean()
        }
  def evaluate_account_margin(wallet_balance, positions) when is_list(positions) do
    total_unrealized_pnl =
      positions
      |> Enum.map(&Map.get(&1, :unrealized_pnl, 0.0))
      |> Enum.sum()

    account_equity = Float.round(wallet_balance + total_unrealized_pnl, 2)

    total_notional =
      positions
      |> Enum.map(&Map.get(&1, :notional, 0.0))
      |> Enum.sum()

    initial_margin_used =
      positions
      |> Enum.map(fn pos ->
        notional = Map.get(pos, :notional, 0.0)
        lev = max(Map.get(pos, :leverage, 1), 1)
        notional / lev
      end)
      |> Enum.sum()
      |> Float.round(2)

    # Standard Maintenance Margin Rate = 1%
    mmr = 0.01
    maintenance_margin_required = Float.round(total_notional * mmr, 2)

    free_collateral = Float.round(max(account_equity - initial_margin_used, 0.0), 2)

    margin_ratio =
      if account_equity > 0 do
        Float.round(maintenance_margin_required / account_equity * 100.0, 2)
      else
        100.0
      end

    margin_call = margin_ratio >= 80.0

    %{
      account_equity: account_equity,
      total_notional: Float.round(total_notional, 2),
      initial_margin_used: initial_margin_used,
      maintenance_margin_required: maintenance_margin_required,
      free_collateral: free_collateral,
      margin_ratio: margin_ratio,
      margin_call?: margin_call
    }
  end

  @doc """
  Validates if a target leverage is permissible for an asset.
  """
  @spec validate_leverage(String.t(), pos_integer()) :: {:ok, pos_integer()} | {:error, term()}
  def validate_leverage(coin, target_leverage) when is_integer(target_leverage) do
    max_lev = max_leverage_for(coin)

    cond do
      target_leverage < 1 ->
        {:error, :leverage_below_minimum}

      target_leverage > max_lev ->
        {:error, {:leverage_exceeds_maximum, max_lev}}

      true ->
        {:ok, target_leverage}
    end
  end
end
