defmodule Lux.Agents.CoinbaseTradingAgent do
  @moduledoc """
  Autonomous trading agent for Coinbase Advanced Trade.

  Coordinates market surveillance, real-time risk assessment, portfolio rebalancing,
  and order execution via Coinbase lenses, prisms, beams, and signals.
  """
  use Lux.Agent,
    name: "Coinbase Trading Agent",
    description: "Autonomous trading and risk management agent for Coinbase Advanced Trade and Exchange",
    goal: "Surveil crypto markets, enforce portfolio risk boundaries, and execute optimized trades on Coinbase",
    capabilities: [:market_surveillance, :portfolio_management, :risk_enforcement, :order_execution],
    lenses: [
      Lux.Lenses.Coinbase.MarketDataLens,
      Lux.Lenses.Coinbase.AccountLens,
      Lux.Lenses.Coinbase.OrderLens
    ],
    prisms: [
      Lux.Prisms.Coinbase.RestClientPrism,
      Lux.Prisms.Coinbase.WebsocketFeedPrism,
      Lux.Prisms.Coinbase.OrderExecutionPrism,
      Lux.Prisms.Coinbase.PortfolioSyncPrism
    ],
    accepts_signals: [
      Lux.Schemas.Coinbase.TickerSchema,
      Lux.Schemas.Coinbase.OrderSchema,
      Lux.Schemas.Coinbase.PortfolioSchema
    ],
    signal_handlers: [
      {Lux.Schemas.Coinbase.OrderSchema, Lux.Prisms.Coinbase.OrderExecutionPrism},
      {Lux.Schemas.Coinbase.PortfolioSchema, Lux.Prisms.Coinbase.PortfolioSyncPrism}
    ],
    llm_config: %{
      model: "gpt-4o-mini",
      temperature: 0.2,
      json_response: true,
      messages: [
        %{
          role: "system",
          content: """
          You are the Coinbase Autonomous Trading Agent in the Lux Framework.
          You analyze cryptocurrency markets, evaluate real-time orderbook dynamics,
          enforce portfolio risk constraints (concentration and drawdowns), and execute
          trades on Coinbase Advanced Trade via configured lenses, prisms, and beams.
          """
        }
      ]
    }
end
