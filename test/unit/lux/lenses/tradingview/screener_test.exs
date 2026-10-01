defmodule Lux.Lenses.TradingView.ScreenerTest do
  use ExUnit.Case, async: true
  alias Lux.Lenses.TradingView.Screener

  test "before_focus format" do
    {:ok, payload} = Screener.before_focus(%{market: "crypto"})
    assert is_map(payload)
    assert payload["options"]["lang"] == "en"
  end
end
