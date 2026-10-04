defmodule Lux.Schemas.Coinbase do
  @moduledoc """
  Unified schema registry and validation helpers for Coinbase Advanced Trade.
  """

  alias Lux.Schemas.Coinbase.{OrderSchema, PortfolioSchema, TickerSchema}

  @doc """
  Returns the TickerSchema module.
  """
  def ticker_schema, do: TickerSchema

  @doc """
  Returns the OrderSchema module.
  """
  def order_schema, do: OrderSchema

  @doc """
  Returns the PortfolioSchema module.
  """
  def portfolio_schema, do: PortfolioSchema
end
