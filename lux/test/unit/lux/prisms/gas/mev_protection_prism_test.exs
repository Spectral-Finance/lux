defmodule Lux.Prisms.Gas.MEVProtectionPrismTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Gas.MEVProtectionPrism

  describe "handler/2 - basic functionality" do
    test "returns MEV risk analysis for simple transfer" do
      result = MEVProtectionPrism.handler(%{
        tx_data: %{
          to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601",
          value: "1000000000000000000"
        },
        network: "mainnet"
      })

      assert {:ok, analysis} = result
      assert analysis.mev_risk_level in ["low", "medium", "high", "critical"]
      assert is_number(analysis.mev_risk_score)
      assert analysis.mev_risk_score >= 0.0 and analysis.mev_risk_score <= 1.0
      assert is_list(analysis.risk_factors)
      assert is_binary(analysis.recommended_relay)
      assert is_map(analysis.relay_endpoints)
      assert is_integer(analysis.estimated_mev_exposure_wei)
      assert is_binary(analysis.protection_recommendation)
    end

    test "detects DEX interaction as high risk" do
      result = MEVProtectionPrism.handler(%{
        tx_data: %{
          to: "0x7a250d5c35b8bC8d5F5C0c6C3C3c3c3c3c3c3c3c",
          value: "0",
          data: "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"
        },
        network: "mainnet",
        gas_price_gwei: 80
      })

      assert {:ok, analysis} = result
      # DEX + calldata + high gas = elevated risk
      risk_idx = Enum.find_index(analysis.risk_factors, fn f ->
        String.contains?(String.downcase(f), "dex") or String.contains?(String.downcase(f), "frontrunning")
      end)
      assert risk_idx != nil
    end

    test "detects high value transactions" do
      result = MEVProtectionPrism.handler(%{
        tx_data: %{
          to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601",
          value: "50000000000000000000"  # 50 ETH
        },
        network: "mainnet"
      })

      assert {:ok, analysis} = result
      high_value_idx = Enum.find_index(analysis.risk_factors, fn f ->
        String.contains?(String.downcase(f), "high transaction value")
      end)
      assert high_value_idx != nil
    end

    test "recommends flashbots for high risk" do
      result = MEVProtectionPrism.handler(%{
        tx_data: %{
          to: "0x7a250d5c35b8bC8d5F5C0c6C3C3c3c3c3c3c3c3c",
          value: "0",
          data: "0xabcdef1234567890"
        },
        network: "mainnet",
        gas_price_gwei: 150
      })

      assert {:ok, analysis} = result
      assert analysis.recommended_relay in ["flashbots", "eden", "avo"]
    end

    test "low risk suggests default relay" do
      result = MEVProtectionPrism.handler(%{
        tx_data: %{
          to: "0xd3cDA913deb6F67967B99D67aCdF1712C293601",
          value: "100000000000000000"  # 0.1 ETH
        },
        network: "mainnet"
      })

      assert {:ok, analysis} = result
      assert analysis.recommended_relay == "default"
    end

    test "handles missing tx_data gracefully" do
      result = MEVProtectionPrism.handler(%{})

      assert {:ok, analysis} = result
      assert analysis.mev_risk_level == "low"
    end

    test "includes relay endpoints for recommended relay" do
      result = MEVProtectionPrism.handler(%{
        tx_data: %{
          to: "0x7a250d5c35b8bC8d5F5C0c6C3C3c3c3c3c3c3c3c",
          data: "0xabc"
        }
      })

      assert {:ok, analysis} = result
      assert is_map(analysis.relay_endpoints)
      assert Map.has_key?(analysis.relay_endpoints, "mainnet")
    end
  end
