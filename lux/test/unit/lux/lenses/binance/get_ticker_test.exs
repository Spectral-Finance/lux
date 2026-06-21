defmodule Lux.Lenses.Binance.GetTickerTest do
  use ExUnit.Case, async: true
  
  alias Lux.Lenses.Binance.GetTicker

  describe "GetTicker Lens" do
    test "before_focus formats spot URL correctly" do
      params = %{symbol: "BTCUSDT", network: "spot"}
      lens = struct(GetTicker)
      
      {:ok, updated_lens} = GetTicker.before_focus(params, lens)
      
      assert updated_lens.url == "https://api.binance.com/api/v3/ticker/price"
      assert updated_lens.params.symbol == "BTCUSDT"
    end

    test "before_focus formats futures URL correctly" do
      params = %{symbol: "ETHUSDT", network: "futures"}
      lens = struct(GetTicker)
      
      {:ok, updated_lens} = GetTicker.before_focus(params, lens)
      
      assert updated_lens.url == "https://fapi.binance.com/fapi/v1/ticker/price"
      assert updated_lens.params.symbol == "ETHUSDT"
    end

    test "after_focus handles successful response" do
      response = %{
        "symbol" => "BTCUSDT",
        "price" => "65000.00"
      }
      
      assert {:ok, result} = GetTicker.after_focus(response)
      assert result.symbol == "BTCUSDT"
      assert result.price == "65000.00"
    end

    test "after_focus handles error response" do
      error_response = %{
        "msg" => "Invalid symbol",
        "code" => -1121
      }
      
      assert {:error, %{message: "Invalid symbol", code: -1121}} = GetTicker.after_focus(error_response)
    end
  end
end
