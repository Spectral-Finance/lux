defmodule Lux.Defi.UniswapV3Test do
  use ExUnit.Case, async: true
  alias Lux.Defi.UniswapV3

  test "selects optimal fee tier quote and computes slippage minimum" do
    {:ok, quote} =
      UniswapV3.quote_exact_input(
        %{
          token_in: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
          token_out: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
          amount_in: 1_000_000,
          slippage_bps: 50
        },
        quoter_fn: fn _in, _out, amt, fee ->
          if fee == 500, do: {:ok, amt * 2500}, else: {:ok, amt * 2480}
        end
      )

    assert quote.fee_tier == 500
    assert quote.expected_amount_out == 2_500_000_000
    assert quote.amount_out_minimum == 2_487_500_000
  end

  test "evaluates concentrated liquidity position range and recommends rebalance when out of range" do
    {:ok, in_pos} =
      UniswapV3.evaluate_position(%{
        tick_lower: -1000,
        tick_upper: 1000,
        current_tick: 100,
        liquidity: 50_000_000
      })

    assert in_pos.in_range == true
    assert in_pos.recommended_action == :hold

    {:ok, out_pos} =
      UniswapV3.evaluate_position(%{
        tick_lower: -1000,
        tick_upper: 1000,
        current_tick: 1500,
        liquidity: 50_000_000
      })

    assert out_pos.in_range == false
    assert out_pos.recommended_action == :rebalance_immediately
    assert out_pos.suggested_new_range == %{tick_lower: 500, tick_upper: 2500}
  end
end
