defmodule Lux.Prisms.Curve.RemoveLiquidityPrism do
  @moduledoc """
  Prism for removing liquidity from Curve pools.
  """

  alias Lux.{Client, Prisms}

  def remove_liquidity(pool_id, user_address, amount) do
    with {:ok, response} <- Client.post("/curve/remove_liquidity", %{
      pool_id: pool_id,
      user_address: user_address,
      amount: amount
    }) do
      {:ok, response.body}
    else
      error -> {:error, error}
    end
  end
end