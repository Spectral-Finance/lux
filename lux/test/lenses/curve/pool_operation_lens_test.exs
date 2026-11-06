defmodule Lux.Lenses.Curve.PoolOperationLensTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.Curve.PoolOperationLens

  test "successfully executes add_liquidity operation" do
    params = %{
      pool_address: "0xbEbc44782c7dB0a1a60Cbfece978e5f975e136Eb",
      action: :add_liquidity,
      amounts: ["1000000", "1000000"],
      min_mint_amount: "1990000"
    }

    assert {:ok, result} = PoolOperationLens.focus(params)
    assert result.result.status == "success"
    assert result.action == :add_liquidity
  end

  test "returns error on invalid action" do
    params = %{
      pool_address: "0xbEbc44782c7dB0a1a60Cbfece978e5f975e136Eb",
      action: :invalid_action
    }

    assert {:error, {:unknown_action, :invalid_action}} = PoolOperationLens.focus(params)
  end
end
