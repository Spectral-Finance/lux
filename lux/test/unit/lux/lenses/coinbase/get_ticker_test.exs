defmodule Lux.Lenses.Coinbase.GetTickerTest do
  use ExUnit.Case, async: true
  alias Lux.Lenses.Coinbase.GetTicker

  test "before_focus formats URL correctly" do
    params = %{product_id: "BTC-USD"}
    lens = struct(GetTicker)
    {:ok, updated_lens} = GetTicker.before_focus(params, lens)
    assert updated_lens.url == "https://api.coinbase.com/api/v3/brokerage/products/BTC-USD"
  end

  test "after_focus handles successful response" do
    response = %{"product_id" => "BTC-USD", "price" => "65000.00"}
    assert {:ok, result} = GetTicker.after_focus(response)
    assert result.product_id == "BTC-USD"
    assert result.price == "65000.00"
  end
end
