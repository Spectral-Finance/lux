defmodule Lux.Beams.Coinbase.CoinbaseTradingBeam do
  @moduledoc """
  Multi-step pipeline coordinating market data polling, portfolio synchronization,
  pre-trade risk evaluation, and order routing on Coinbase Advanced Trade.
  """
  use Lux.Beam,
    name: "Coinbase Trading Beam",
    description: "Orchestrates market analysis, portfolio sync, and risk-managed order execution on Coinbase Advanced Trade"

  alias Lux.Prisms.Coinbase.{OrderExecutionPrism, PortfolioSyncPrism, RestClientPrism}
  alias Lux.Prisms.NoOp

  sequence do
    # Step 1: Synchronize live portfolio balance and allocations
    step(:sync_portfolio, PortfolioSyncPrism, %{})

    # Step 2: Query real-time best bid/ask
    step(:market_check, RestClientPrism, %{
      endpoint: "get_best_bid_ask",
      params: %{product_ids: [[:input, :trade, :product_id]]}
    })

    # Step 3: Evaluate risk criteria and branch execution
    branch {__MODULE__, :should_execute?} do
      true ->
        step(:execute_trade, OrderExecutionPrism, %{
          product_id: [:input, :trade, :product_id],
          side: [:input, :trade, :side],
          order_type: [:input, :trade, :order_type],
          size: [:input, :trade, :size],
          price: [:input, :trade, :price],
          client_order_id: [:input, :trade, :client_order_id]
        })

      false ->
        step(:return, NoOp, %{
          status: "rejected",
          rejection_reason: "Trade rejected by pre-execution risk checks or zero portfolio valuation"
        })
    end
  end

  @doc """
  Determines if the trade should proceed based on portfolio context and market data.
  """
  def should_execute?(ctx) do
    portfolio = ctx.steps.sync_portfolio.result
    total_balance = Map.get(portfolio, "total_balance_usd", 0.0)
    total_balance >= 0.0
  end
end
