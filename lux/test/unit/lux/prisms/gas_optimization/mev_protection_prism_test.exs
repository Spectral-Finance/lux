defmodule Lux.Prisms.GasOptimization.MEVProtectionPrismTest do
  use UnitAPICase, async: false

  alias Lux.Prisms.GasOptimization.MEVProtectionPrism

  describe "handler/2" do
    test "analyzes DEX swap for MEV risk" do
      input = %{
        transaction: %{
          to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
          data: "0x38ed1739",
          value: "1000000000000000000",
          type: "swap",
          slippage_tolerance: 1.0
        },
        value_eth: 5.0
      }

      assert {:ok, result} = MEVProtectionPrism.handler(input, nil)

      assert result.risk_level in ["medium", "high", "critical"]
      assert "sandwich_attack" in result.mev_risks
      assert length(result.recommended_protections) > 0
      assert result.estimated_mev_exposure_eth > 0
      assert result.detected_tx_type == "swap"
    end

    test "classifies simple ETH transfer as low risk" do
      input = %{
        transaction: %{
          to: "0x742d35Cc6634C0532925a3b844Bc9e7595f2bD18",
          data: "0x",
          value: "1000000000000000000"
        },
        value_eth: 1.0
      }

      assert {:ok, result} = MEVProtectionPrism.handler(input, nil)

      assert result.risk_level in ["none", "low"]
      assert result.detected_tx_type == "transfer"
    end

    test "detects high risk for large swap with high slippage" do
      input = %{
        transaction: %{
          to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
          data: "0x38ed1739",
          type: "swap",
          slippage_tolerance: 5.0
        },
        value_eth: 15.0
      }

      assert {:ok, result} = MEVProtectionPrism.handler(input, nil)

      assert result.risk_level in ["high", "critical"]
      assert "excessive_slippage" in result.mev_risks
      assert "sandwich_attack" in result.mev_risks
    end

    test "recommends Flashbots for high-risk transactions" do
      input = %{
        transaction: %{
          to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
          data: "0x38ed1739",
          type: "swap",
          slippage_tolerance: 2.0
        },
        value_eth: 10.0,
        network: "mainnet"
      }

      assert {:ok, result} = MEVProtectionPrism.handler(input, nil)

      methods = Enum.map(result.recommended_protections, & &1.method)
      assert "flashbots_protect" in methods or "private_mempool" in methods
    end

    test "detects token approval as low risk" do
      input = %{
        transaction: %{
          to: "0x6B175474E89094C44Da98b954EedeAC495271d0F",
          data: "0x095ea7b3",
          value: "0"
        },
        value_eth: 0
      }

      assert {:ok, result} = MEVProtectionPrism.handler(input, nil)

      assert result.risk_level in ["none", "low"]
      assert result.detected_tx_type == "approval"
    end

    test "includes safe submission methods" do
      input = %{
        transaction: %{
          to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
          data: "0x38ed1739",
          type: "swap"
        },
        value_eth: 5.0
      }

      assert {:ok, result} = MEVProtectionPrism.handler(input, nil)

      assert is_list(result.safe_submission_methods)
      assert length(result.safe_submission_methods) > 0
    end

    test "handles missing transaction fields gracefully" do
      input = %{
        transaction: %{to: "0xabc"}
      }

      assert {:ok, result} = MEVProtectionPrism.handler(input, nil)

      assert result.risk_level in ["none", "low"]
    end
  end

  describe "detect_transaction_type/1" do
    test "detects swap from selector" do
      tx = %{to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", data: "0x38ed1739abcdef"}
      assert MEVProtectionPrism.detect_transaction_type(tx) == "swap"
    end

    test "detects transfer when no data" do
      tx = %{to: "0xabc", data: "0x"}
      assert MEVProtectionPrism.detect_transaction_type(tx) == "transfer"
    end

    test "detects approval" do
      tx = %{to: "0xabc", data: "0x095ea7b3abcdef"}
      assert MEVProtectionPrism.detect_transaction_type(tx) == "approval"
    end

    test "respects explicit type" do
      tx = %{to: "0xabc", data: "0xabcdef", type: "swap"}
      assert MEVProtectionPrism.detect_transaction_type(tx) == "swap"
    end

    test "classifies unknown data as contract_call" do
      tx = %{to: "0xabc", data: "0xdeadbeef12345678"}
      assert MEVProtectionPrism.detect_transaction_type(tx) == "contract_call"
    end

    test "detects liquidity operations" do
      tx = %{to: "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D", data: "0xe8e33700abcdef"}
      assert MEVProtectionPrism.detect_transaction_type(tx) == "liquidity"
    end
  end

  describe "analyze_mev_risks/3" do
    test "identifies sandwich risk for swaps" do
      tx = %{to: "0xabc", data: "0x38ed1739", slippage_tolerance: 1.0}
      risks = MEVProtectionPrism.analyze_mev_risks(tx, "swap", 5.0)

      risk_types = Enum.map(risks, & &1.type)
      assert "sandwich_attack" in risk_types
    end

    test "identifies frontrunning risk for large contract calls" do
      tx = %{to: "0xabc", data: "0xdeadbeef"}
      risks = MEVProtectionPrism.analyze_mev_risks(tx, "contract_call", 2.0)

      risk_types = Enum.map(risks, & &1.type)
      assert "frontrunning" in risk_types
    end

    test "no risks for small transfers" do
      tx = %{to: "0xabc", data: "0x"}
      risks = MEVProtectionPrism.analyze_mev_risks(tx, "transfer", 0.01)

      assert Enum.empty?(risks)
    end

    test "identifies excessive slippage" do
      tx = %{to: "0xabc", data: "0x", slippage_tolerance: 10.0}
      risks = MEVProtectionPrism.analyze_mev_risks(tx, "transfer", 0)

      risk_types = Enum.map(risks, & &1.type)
      assert "excessive_slippage" in risk_types
    end
  end

  describe "view/0" do
    test "returns prism struct" do
      prism = MEVProtectionPrism.view()

      assert prism.name == "MEV Protection Analyzer"
      assert prism.description =~ "MEV"
    end
  end
end
