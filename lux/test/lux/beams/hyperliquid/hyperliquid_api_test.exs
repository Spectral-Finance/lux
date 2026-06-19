defmodule Lux.Beams.Hyperliquid.HyperliquidAPITest do
  use ExUnit.Case, async: true

  test "fetch_positions/1 returns error for invalid address" do
    result = Lux.Beams.Hyperliquid.HyperliquidAPI.fetch_positions("0x0000000000000000000000000000000000000000")
    assert match?({:error, _}, result)
  end

  test "parse_entry handles nil" do
    assert Lux.Beams.Hyperliquid.HyperliquidAPI.parse_entry(%{}, "test") == 0.0
  end

  test "parse_entry handles float string" do
    assert Lux.Beams.Hyperliquid.HyperliquidAPI.parse_entry(%{"test" => "1.5"}, "test") == 1.5
  end
end
