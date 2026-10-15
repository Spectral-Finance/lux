defmodule Lux.Defi.SushiSwapTest do
  use ExUnit.Case, async: true
  alias Lux.Defi.SushiSwap

  test "selects best SushiXSwap cross-chain bridge route by net output" do
    req = %{source_chain: :arbitrum, dest_chain: :base, amount_in: 1000.0, slippage_bps: 50}

    routes = [
      %{adapter: :stargate, bridge_fee_usd: 1.5, exchange_rate: 1.0, estimated_time_sec: 45},
      %{adapter: :axelar, bridge_fee_usd: 4.0, exchange_rate: 1.0, estimated_time_sec: 90}
    ]

    {:ok, best} = SushiSwap.quote_cross_chain_swap(req, routes)
    assert best.bridge_adapter == :stargate
    assert best.expected_amount_out == 998.5
    assert best.min_amount_out == 993.5075
  end
end
