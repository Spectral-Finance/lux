defmodule Lux.Defi.SushiSwap.SushiXSwapTest do
  use UnitCase, async: true

  alias Lux.Defi.SushiSwap.SushiXSwap

  describe "quote_cross_chain_swap/7" do
    test "quotes cross-chain transfer from Ethereum to Arbitrum" do
      # 1 ETH @ $2500 -> Arbitrum USDC @ $1.0
      assert {:ok, quote} =
               SushiXSwap.quote_cross_chain_swap(1, 42161, "WETH", "USDC", 1.0, 2500.0, 1.0)

      assert quote.src_chain == 1
      assert quote.dst_chain == 42161
      assert quote.amount_in == 1.0
      assert quote.estimated_amount_out > 2400.0
      assert quote.min_amount_out < quote.estimated_amount_out
      assert quote.total_fee_usd > 0.0
      assert quote.protocol =~ "SushiXSwap"
    end

    test "rejects same-chain swap attempt" do
      assert {:error, :same_chain_route} =
               SushiXSwap.quote_cross_chain_swap(1, 1, "WETH", "USDC", 1.0, 2500.0, 1.0)
    end
  end
end
