defmodule Lux.Integrations.SushiSwap.BridgeTest do
  use UnitAPICase, async: true

  alias Lux.Integrations.SushiSwap
  alias Lux.Integrations.SushiSwap.Bridge

  describe "bridge_quote/2" do
    test "builds cross-chain bridge quote request" do
      assert {:ok, quote} =
               Bridge.bridge_quote(%{
                 from_chain: :ethereum,
                 to_chain: :base,
                 token_in: "0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee",
                 token_out: "0x4200000000000000000000000000000000000006",
                 amount: "1000",
                 recipient: "0x0000000000000000000000000000000000000001",
                 slippage: 0.01
               })

      assert quote.from_chain_id == 1
      assert quote.to_chain_id == 8453
      assert quote.required_confirmations == 20
      assert quote.quote.estimated_amount_out == 990.0
    end

    test "rejects same-chain bridge quote" do
      assert {:error, :same_chain} =
               Bridge.bridge_quote(%{from_chain: :ethereum, to_chain: :ethereum})
    end
  end

  describe "optimize_routes/2" do
    test "selects best risk-adjusted route" do
      routes =
        Bridge.optimize_routes([
          %{
            provider: :lifi,
            estimated_amount_out: 1000,
            gas_usd: 10,
            price_impact: 0.005,
            eta_seconds: 300,
            liquidity_usd: 1_000_000
          },
          %{
            provider: :unknown,
            estimated_amount_out: 1100,
            gas_usd: 2,
            price_impact: 0.10,
            eta_seconds: 3_600,
            liquidity_usd: 10_000
          }
        ])

      assert hd(routes).provider == :lifi
      assert hd(routes).alerts == []
      assert Enum.at(routes, 1).alerts != []
    end
  end

  describe "verify_bridge_security/2" do
    test "returns alerts for unsafe bridge route" do
      assert {:error, alerts} =
               Bridge.verify_bridge_security(%{
                 provider: :unknown,
                 price_impact: 0.10,
                 gas_usd: 200,
                 liquidity_usd: 1_000,
                 eta_seconds: 4_000
               })

      assert "bridge provider is not allowed" in alerts
      assert "price impact exceeds policy" in alerts
      assert "gas estimate exceeds policy" in alerts
      assert "route liquidity is below policy" in alerts
      assert "bridge ETA exceeds policy" in alerts
    end
  end

  describe "position and reward helpers" do
    test "tracks positions and optimizes rewards" do
      positions =
        Bridge.position_tracking(
          [
            %{pool: "SUSHI/USDC", token_a: "sushi", amount_a: 100, token_b: "usdc", amount_b: 250}
          ],
          %{"sushi" => 1.5, "usdc" => 1.0}
        )

      assert positions.total_value_usd == 400.0

      farms =
        Bridge.reward_optimization([
          %{pool: "safe", apr: 0.08, reward_apr: 0.02, risk_score: 0.01},
          %{pool: "risky", apr: 0.20, reward_apr: 0.05, risk_score: 0.50}
        ])

      assert hd(farms).pool == "safe"
    end

    test "builds liquidity plan" do
      plan =
        Bridge.liquidity_plan(%{
          pool: "ETH/USDC",
          token_a_value_usd: 800,
          token_b_value_usd: 200
        })

      assert plan.action == :add_token_b_or_remove_token_a
      assert_in_delta plan.rebalance_value_usd, 300.0, 0.001
    end
  end

  describe "chain helpers" do
    test "resolve chain ids without dynamic atoms" do
      assert SushiSwap.chain_id(:base) == 8453
      assert SushiSwap.chain_id("Base") == 8453
      assert SushiSwap.chain_key("42161") == :arbitrum
    end
  end
end
