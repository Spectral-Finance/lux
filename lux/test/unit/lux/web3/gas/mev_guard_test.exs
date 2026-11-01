defmodule Lux.Web3.Gas.MevGuardTest do
  use ExUnit.Case, async: true

  alias Lux.Web3.Gas.MevGuard

  describe "analyze_vulnerability/1" do
    test "flags high slippage DEX trades as critical risk" do
      trade = %{
        action_type: :swap,
        slippage_percentage: 3.5,
        value_eth: 5.0
      }

      report = MevGuard.analyze_vulnerability(trade)
      assert report.risk_level == :critical
      assert report.requires_private_relay == true
      assert report.recommended_route == :flashbots
      assert length(report.recommendations) > 0
    end

    test "flags low value simple transfers as low risk" do
      tx = %{
        action_type: :transfer,
        slippage_percentage: 0.0,
        value_eth: 0.5
      }

      report = MevGuard.analyze_vulnerability(tx)
      assert report.risk_level == :low
      assert report.requires_private_relay == false
    end
  end

  describe "build_private_bundle/3" do
    test "constructs valid eth_sendBundle JSON-RPC payload" do
      signed = ["0x010203", "0x040506"]
      bundle = MevGuard.build_private_bundle(signed, 19_000_000)

      assert bundle.method == "eth_sendBundle"
      assert [params] = bundle.params
      assert params.txs == signed
      assert params.blockNumber == "0x121eac0"
    end
  end
end
