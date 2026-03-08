defmodule Lux.Integrations.Web3.Gas.MevProtectionTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.Gas.MevProtection

  setup do
    Req.Test.stub(Lux.Web3.FlashbotsMock, fn conn ->
      {:ok, body, _} = Plug.Conn.read_body(conn)
      req = Jason.decode!(body)

      result = case req["method"] do
        "eth_sendPrivateTransaction" -> "0xtxhash123"
        "eth_sendBundle" -> %{"bundleHash" => "0xbundlehash"}
        "eth_cancelPrivateTransaction" -> true
        _ -> nil
      end

      Req.Test.json(conn, %{"jsonrpc" => "2.0", "id" => 1, "result" => result})
    end)
    :ok
  end

  test "send_private_transaction" do
    assert {:ok, "0xtxhash123"} =
      MevProtection.send_private_transaction("0xf86c...", plug: {Req.Test, Lux.Web3.FlashbotsMock})
  end

  test "send_private_transaction with max_block" do
    assert {:ok, "0xtxhash123"} =
      MevProtection.send_private_transaction("0xf86c...",
        max_block_number: 19000000,
        plug: {Req.Test, Lux.Web3.FlashbotsMock})
  end

  test "send_bundle" do
    assert {:ok, %{"bundleHash" => _}} =
      MevProtection.send_bundle(["0xtx1", "0xtx2"], 19000000, plug: {Req.Test, Lux.Web3.FlashbotsMock})
  end

  test "cancel_private_transaction" do
    assert {:ok, true} =
      MevProtection.cancel_private_transaction("0xtxhash", plug: {Req.Test, Lux.Web3.FlashbotsMock})
  end

  test "assess_mev_risk — low risk for simple ETH transfer" do
    result = MevProtection.assess_mev_risk(%{to: "0xabc", value: 1000})
    assert result.risk_level == :low
    assert result.use_flashbots == false
  end

  test "assess_mev_risk — medium risk for DEX swap" do
    result = MevProtection.assess_mev_risk(%{
      to: "0xrouter",
      value: 500_000_000_000_000_000,
      data: "0x38ed1739000000..."  # swapExactTokensForTokens
    })
    assert result.risk_level == :medium
    assert :uniswap_swap in result.risk_factors
    assert result.use_flashbots == true
  end

  test "assess_mev_risk — high risk for large DEX swap" do
    result = MevProtection.assess_mev_risk(%{
      to: "0xrouter",
      value: 10_000_000_000_000_000_000,  # 10 ETH
      data: "0x7ff36ab5000000..."  # swapExactETHForTokens
    })
    assert result.risk_level == :high
    assert :high_value in result.risk_factors
    assert :uniswap_swap in result.risk_factors
    assert result.recommendation =~ "Flashbots"
  end

  test "protect_rpc_url returns Flashbots Protect URL" do
    assert MevProtection.protect_rpc_url() == "https://protect.flashbots.net"
  end
end
