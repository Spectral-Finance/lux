defmodule Lux.Prisms.Curve.AddLiquidityPrism do
  @moduledoc """
  Module for adding liquidity to Curve stablecoin pools with slippage protection.
  """

  alias Lux.Services.Curve

  def add_liquidity(pool_id, amounts, slippage_tolerance) do
    Curve.add_liquidity(pool_id, amounts, slippage_tolerance)
  end
end