defmodule Lux.Web3.Gas.MEVProtectionTest do
  use UnitAPICase, async: true

  alias Lux.Web3.Gas.MEVProtection

  describe "analyze/1" do
    test "returns low risk for simple ETH transfer" do
      tx = %{to: "0x1234567890abcdef1234567890abcdef12345678", value: 100_000_000_000_000_000, data: "0x"}

      assert {:ok, analysis} = MEVProtection.analyze(tx)
      assert analysis.risk_level == :low
      assert analysis.is_front_running_risk == false
      assert analysis.is_sandwich_attack_risk == false
      assert analysis.recommended_private_relay == false
    end

    test "returns high risk for large DEX swap" do
      tx = %{to: "0x7a250d5c35b", value: 5_000_000_000_000_000_000, data: "0x38ed17390000"}

      assert {:ok, analysis} = MEVProtection.analyze(tx)
      assert analysis.risk_level == :high
      assert analysis.is_front_running_risk == true
      assert analysis.is_sandwich_attack_risk == true
      assert analysis.recommended_private_relay == true
      assert length(analysis.suggestions) > 0
    end

    test "returns medium risk for small DEX swap" do
      tx = %{to: "0x7a250d5c35b", value: 0, data: "0x38ed17390000"}

      assert {:ok, analysis} = MEVProtection.analyze(tx)
      assert analysis.risk_level == :medium
      assert analysis.is_sandwich_attack_risk == true
    end

    test "returns medium risk for large transfer to unknown address" do
      tx = %{to: "0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef", value: 10_000_000_000_000_000_000, data: "0x"}

      assert {:ok, analysis} = MEVProtection.analyze(tx)
      assert analysis.risk_level == :medium
      assert analysis.is_front_running_risk == true
    end
  end

  describe "is_dex_interaction?/1" do
    test "recognizes known DEX routers" do
      assert MEVProtection.is_dex_interaction?("0x7a250d5c35b")
      assert MEVProtection.is_dex_interaction?("0xe592427a0ae")
      assert MEVProtection.is_dex_interaction?("0x1111111111111111111111111111111111111111")
    end

    test "rejects non-DEX addresses" do
      refute MEVProtection.is_dex_interaction?("0x1234567890abcdef1234567890abcdef12345678")
    end
  end
end
