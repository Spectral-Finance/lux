defmodule Lux.Prisms.PancakeSwap.CrossChainPlanPrismTest do
  use UnitAPICase, async: true

  alias Lux.Prisms.PancakeSwap.CrossChainPlanPrism

  @ctx %{name: "TestAgent"}

  describe "handler/2" do
    test "recommends moving capital to the chain with the best APR" do
      assert {:ok, result} =
               CrossChainPlanPrism.handler(
                 %{
                   chains: [
                     %{chain: "bsc", apr: 0.12, position_usd: 20_000},
                     %{chain: "arbitrum", apr: 0.35, position_usd: 0},
                     %{chain: "base", apr: 0.2, position_usd: 5_000}
                   ],
                   bridge_fee_usd: 15,
                   token: "CAKE"
                 },
                 @ctx
               )

      assert result.recommended
      assert result.best_chain == "arbitrum"
      assert result.horizon_days == 365
      assert result.reason =~ "Move 2 position(s) to arbitrum"

      assert [first, second] = result.moves

      # bsc: 20_000 * (0.35 - 0.12) = 4600 gross, 4585 net
      assert first.from_chain == "bsc"
      assert first.to_chain == "arbitrum"
      assert first.from_chain_id == 56
      assert first.to_chain_id == 42_161
      assert first.amount_usd == 20_000
      assert_in_delta first.gross_gain_usd, 4_600.0, 1.0e-6
      assert_in_delta first.net_gain_usd, 4_585.0, 1.0e-6
      assert first.bridge_fee_usd == 15

      # base: 5_000 * (0.35 - 0.2) = 750 gross, 735 net
      assert second.from_chain == "base"
      assert_in_delta second.net_gain_usd, 735.0, 1.0e-6

      assert [step] = first.steps

      assert %{
               name: "bridge",
               type: "bridge",
               from_chain_id: 56,
               to_chain_id: 42_161,
               amount_usd: 20_000,
               token: "CAKE"
             } = step

      refute Map.has_key?(second.steps |> hd(), :data)
    end

    test "does not move capital when the gain does not beat the bridge fee" do
      assert {:ok, result} =
               CrossChainPlanPrism.handler(
                 %{
                   chains: [
                     %{chain: "bsc", apr: 0.12, position_usd: 1_000},
                     %{chain: "base", apr: 0.14, position_usd: 0}
                   ],
                   bridge_fee_usd: 15
                 },
                 @ctx
               )

      # gross gain 1000 * 0.02 = 20, minus 15 = 5 net: positive, so still a move
      assert result.recommended

      assert {:ok, no_move} =
               CrossChainPlanPrism.handler(
                 %{
                   chains: [
                     %{chain: "bsc", apr: 0.12, position_usd: 1_000},
                     %{chain: "base", apr: 0.14, position_usd: 0}
                   ],
                   bridge_fee_usd: 25
                 },
                 @ctx
               )

      refute no_move.recommended
      assert no_move.moves == []
      assert no_move.best_chain == "base"
      assert no_move.reason =~ "No move beats the bridge cost"
    end

    test "honours min_gain_usd and horizon_days" do
      chains = [
        %{chain: "bsc", apr: 0.1, position_usd: 10_000},
        %{chain: "base", apr: 0.3, position_usd: 0}
      ]

      # 10_000 * 0.2 * 30/365 = 164.38 gross
      assert {:ok, %{recommended: true, moves: [move]}} =
               CrossChainPlanPrism.handler(
                 %{chains: chains, horizon_days: 30, bridge_fee_usd: 10},
                 @ctx
               )

      assert_in_delta move.gross_gain_usd, 164.383561, 1.0e-5
      assert_in_delta move.net_gain_usd, 154.383561, 1.0e-5

      assert {:ok, %{recommended: false}} =
               CrossChainPlanPrism.handler(
                 %{chains: chains, horizon_days: 30, bridge_fee_usd: 10, min_gain_usd: 200},
                 @ctx
               )
    end

    test "keeps capital on the best chain" do
      assert {:ok, %{recommended: false, best_chain: "bsc", moves: []}} =
               CrossChainPlanPrism.handler(
                 %{
                   chains: [
                     %{chain: "bsc", apr: 0.4, position_usd: 9_000},
                     %{chain: "base", apr: 0.1, position_usd: 0}
                   ]
                 },
                 @ctx
               )
    end

    test "works with a single chain and accepts chain ids and string keys" do
      assert {:ok, %{recommended: false, best_chain: "bsc"}} =
               CrossChainPlanPrism.handler(
                 %{chains: [%{chain: 56, apr: 0.1, position_usd: 100}]},
                 @ctx
               )

      assert {:ok, %{best_chain: "base", recommended: true}} =
               CrossChainPlanPrism.handler(
                 %{
                   "chains" => [
                     %{"chain" => "bsc", "apr" => 0.1, "position_usd" => 10_000},
                     %{"chain" => "base", "apr" => 0.5, "position_usd" => 0}
                   ]
                 },
                 @ctx
               )
    end

    test "rejects unsupported chains" do
      assert {:error, message} =
               CrossChainPlanPrism.handler(
                 %{
                   chains: [
                     %{chain: "bsc", apr: 0.1, position_usd: 1},
                     %{chain: "solana", apr: 0.9, position_usd: 0}
                   ]
                 },
                 @ctx
               )

      assert message =~ "Unsupported chain"
    end

    test "rejects duplicate chains" do
      assert {:error, "each chain may only appear once"} =
               CrossChainPlanPrism.handler(
                 %{
                   chains: [
                     %{chain: "bsc", apr: 0.1, position_usd: 1},
                     %{chain: 56, apr: 0.2, position_usd: 1}
                   ]
                 },
                 @ctx
               )
    end

    test "validates the input" do
      entry = %{chain: "bsc", apr: 0.1, position_usd: 1}

      assert {:error, "chains must be a non-empty list"} =
               CrossChainPlanPrism.handler(%{chains: []}, @ctx)

      assert {:error, "chains must be a non-empty list"} = CrossChainPlanPrism.handler(%{}, @ctx)

      assert {:error, "apr must be a non-negative number"} =
               CrossChainPlanPrism.handler(%{chains: [%{entry | apr: -1}]}, @ctx)

      assert {:error, "position_usd must be a non-negative number"} =
               CrossChainPlanPrism.handler(%{chains: [%{entry | position_usd: nil}]}, @ctx)

      assert {:error, "invalid chain entry: \"bsc\""} =
               CrossChainPlanPrism.handler(%{chains: ["bsc"]}, @ctx)

      assert {:error, "bridge_fee_usd must be a non-negative number"} =
               CrossChainPlanPrism.handler(%{chains: [entry], bridge_fee_usd: -1}, @ctx)

      assert {:error, "horizon_days must be an integer >= 1"} =
               CrossChainPlanPrism.handler(%{chains: [entry], horizon_days: 0}, @ctx)
    end
  end
end
