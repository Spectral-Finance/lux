defmodule Lux.Defi.PancakeSwap.CrossChainRouterTest do
  use UnitCase, async: true

  alias Lux.Defi.PancakeSwap.CrossChainRouter

  describe "quote_bridge/5" do
    test "quotes bridge transfer from BSC to Arbitrum" do
      {:ok, quote} = CrossChainRouter.quote_bridge(56, 42161, "CAKE", 100.0, 2.50)
      assert quote.from_chain == 56
      assert quote.to_chain == 42161
      assert quote.token == "CAKE"
      assert quote.amount == 100.0
      assert quote.estimated_minutes == 3
      assert quote.total_fee_usd > 0
    end

    test "rejects same-chain bridge" do
      assert {:error, :same_chain_bridge} = CrossChainRouter.quote_bridge(56, 56, "CAKE", 10.0)
    end
  end

  describe "plan_bridge/6" do
    test "creates full bridge execution plan" do
      recipient = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
      {:ok, plan} = CrossChainRouter.plan_bridge(56, 1, "USDT", 500.0, recipient, 1.0)

      assert plan.status == :ready_for_execution
      assert plan.recipient == String.downcase(recipient)
      assert String.starts_with?(plan.bridge_id, "brg_")
      assert plan.amount == 500.0
    end
  end
end
