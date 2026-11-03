defmodule Lux.Integrations.Coinbase.AccountManagerTest do
  use UnitCase, async: true

  alias Lux.Integrations.Coinbase.AccountManager

  describe "aggregate_accounts/2" do
    test "aggregates non-zero balances and computes total portfolio USD" do
      accounts = [
        %{
          "uuid" => "acc-1",
          "name" => "USD Wallet",
          "currency" => "USD",
          "available_balance" => %{"value" => "1000.0"},
          "hold" => %{"value" => "500.0"}
        },
        %{
          "uuid" => "acc-2",
          "name" => "BTC Wallet",
          "currency" => "BTC",
          "available_balance" => %{"value" => "0.5"},
          "hold" => %{"value" => "0.0"}
        },
        %{
          "uuid" => "acc-3",
          "name" => "ETH Wallet",
          "currency" => "ETH",
          "available_balance" => %{"value" => "0.0"},
          "hold" => %{"value" => "0.0"}
        }
      ]

      prices = %{"BTC-USD" => 60000.0}

      result = AccountManager.aggregate_accounts(accounts, prices)

      # USD: 1500, BTC: 0.5 * 60000 = 30000 -> Total = 31500
      assert result.total_portfolio_usd == 31500.0
      assert length(result.accounts) == 2
    end
  end

  describe "estimate_trade_fee/5" do
    test "estimates taker fee (60 bps)" do
      # 1.0 BTC @ 50,000 = 50,000 notional. Fee = 50000 * 0.0060 = 300 USD
      fee = AccountManager.estimate_trade_fee(1.0, 50000.0, :taker, 40.0, 60.0)
      assert fee.notional_usd == 50000.0
      assert fee.fee_rate_bps == 60.0
      assert fee.estimated_fee_usd == 300.0
      assert fee.net_notional_usd == 49700.0
    end

    test "estimates maker fee (40 bps)" do
      fee = AccountManager.estimate_trade_fee(1.0, 50000.0, :maker, 40.0, 60.0)
      assert fee.fee_rate_bps == 40.0
      assert fee.estimated_fee_usd == 200.0
    end
  end
end
