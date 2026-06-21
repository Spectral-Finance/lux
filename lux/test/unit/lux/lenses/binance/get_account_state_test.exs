defmodule Lux.Lenses.Binance.GetAccountStateTest do
  use ExUnit.Case, async: true
  
  alias Lux.Lenses.Binance.GetAccountState

  describe "GetAccountState Lens" do
    test "before_focus formats spot URL correctly" do
      params = %{network: "spot"}
      lens = struct(GetAccountState)
      
      {:ok, updated_lens} = GetAccountState.before_focus(params, lens)
      
      assert updated_lens.url == "https://api.binance.com/api/v3/account"
    end

    test "before_focus formats futures URL correctly" do
      params = %{network: "futures"}
      lens = struct(GetAccountState)
      
      {:ok, updated_lens} = GetAccountState.before_focus(params, lens)
      
      assert updated_lens.url == "https://fapi.binance.com/fapi/v2/account"
    end

    test "after_focus handles spot response" do
      response = %{
        "balances" => [
          %{"asset" => "BTC", "free" => "1.5", "locked" => "0.0"},
          %{"asset" => "ETH", "free" => "0.0", "locked" => "0.0"}
        ]
      }
      
      assert {:ok, result} = GetAccountState.after_focus(response)
      assert length(result.balances) == 1
      assert hd(result.balances).asset == "BTC"
      assert hd(result.balances).free == "1.5"
    end

    test "after_focus handles futures response" do
      response = %{
        "assets" => [
          %{"asset" => "USDT", "walletBalance" => "1000.0", "availableBalance" => "900.0"},
          %{"asset" => "BNB", "walletBalance" => "0.0", "availableBalance" => "0.0"}
        ]
      }
      
      assert {:ok, result} = GetAccountState.after_focus(response)
      assert length(result.balances) == 1
      balance = hd(result.balances)
      assert balance.asset == "USDT"
      assert balance.free == "900.0"
      assert balance.locked == "100.0"
    end
  end
end
