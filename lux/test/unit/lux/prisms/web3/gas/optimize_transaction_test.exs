defmodule Lux.Prisms.Web3.Gas.OptimizeTransactionTest do
  use ExUnit.Case, async: true

  alias Lux.Prisms.Web3.Gas.OptimizeTransaction
  alias Lux.Integrations.Web3.Gas.{TransactionManager, Estimator, MevProtection}

  setup do
    {:ok, pid} = TransactionManager.start_link(name: nil)
    %{pid: pid}
  end

  # === Submit ===

  test "submit transaction", %{pid: pid} do
    {:ok, result} = OptimizeTransaction.handler(%{action: "submit", tx: %{to: "0xabc", value: 100}, pid: pid}, [])
    assert result.status == :pending
    assert is_binary(result.id)
  end

  test "submit with gas price", %{pid: pid} do
    {:ok, result} = OptimizeTransaction.handler(%{action: "submit", tx: %{to: "0xabc", gas_price: 30}, pid: pid}, [])
    {:ok, entry} = TransactionManager.status(pid, result.id)
    assert entry.gas_price == 30
  end

  # === Speed Up ===

  test "speed up transaction", %{pid: pid} do
    {:ok, %{id: id}} = TransactionManager.submit(pid, %{to: "0xabc", gas_price: 30})
    {:ok, result} = OptimizeTransaction.handler(%{action: "speed_up", tx_id: id, gas_multiplier: 2.0, pid: pid}, [])
    assert result.new_gas_price == 60
    assert result.speed_ups == 1
  end

  test "speed up not found", %{pid: pid} do
    assert {:error, :not_found} = OptimizeTransaction.handler(%{action: "speed_up", tx_id: "nope", pid: pid}, [])
  end

  test "multiple speed ups", %{pid: pid} do
    {:ok, %{id: id}} = TransactionManager.submit(pid, %{to: "0xabc", gas_price: 10})
    TransactionManager.speed_up(pid, id, 2.0)
    {:ok, result} = TransactionManager.speed_up(pid, id, 1.5)
    assert result.speed_ups == 2
  end

  # === Cancel ===

  test "cancel transaction", %{pid: pid} do
    {:ok, %{id: id}} = TransactionManager.submit(pid, %{to: "0xabc"})
    {:ok, result} = OptimizeTransaction.handler(%{action: "cancel", tx_id: id, pid: pid}, [])
    assert result.status == :cancelled
  end

  test "cancel not found", %{pid: pid} do
    assert {:error, :not_found} = OptimizeTransaction.handler(%{action: "cancel", tx_id: "nope", pid: pid}, [])
  end

  # === Batch ===

  test "batch transactions", %{pid: pid} do
    {:ok, result} = OptimizeTransaction.handler(%{action: "batch", transactions: [%{to: "0xa"}, %{to: "0xb"}, %{to: "0xc"}], pid: pid}, [])
    assert result.count == 3
    assert length(result.batch_ids) == 3
  end

  test "batch empty", %{pid: pid} do
    {:ok, result} = OptimizeTransaction.handler(%{action: "batch", transactions: [], pid: pid}, [])
    assert result.count == 0
  end

  # === Status & List ===

  test "status tracking", %{pid: pid} do
    {:ok, %{id: id}} = TransactionManager.submit(pid, %{to: "0xabc"})
    {:ok, entry} = TransactionManager.status(pid, id)
    assert entry.status == :pending
    assert %DateTime{} = entry.submitted_at
  end

  test "list transactions", %{pid: pid} do
    TransactionManager.submit(pid, %{to: "0xa"})
    TransactionManager.submit(pid, %{to: "0xb"})
    list = TransactionManager.list(pid)
    assert length(list) == 2
  end

  # === Cost Calculation ===

  test "cost calculation ETH only" do
    {:ok, result} = OptimizeTransaction.handler(%{action: "cost", gas_limit: 21_000, gas_price_gwei: 30.0}, [])
    assert result.cost_eth > 0
    assert result.gas_limit == 21_000
    refute Map.has_key?(result, :cost_usd)
  end

  test "cost calculation with USD" do
    {:ok, result} = OptimizeTransaction.handler(%{action: "cost", gas_limit: 21_000, gas_price_gwei: 30.0, eth_price_usd: 2500.0}, [])
    assert result.cost_eth > 0
    assert result.cost_usd > 0
  end

  test "cost high gas" do
    result = Estimator.calculate_cost(500_000, 100.0, 3000.0)
    assert result.cost_eth > 0
    assert result.cost_usd > 0
  end

  # === Gas Estimation via RPC ===

  test "estimate gas with mock RPC" do
    Req.Test.stub(__MODULE__.GasEst, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      decoded = Jason.decode!(body)
      result = case decoded["method"] do
        "eth_estimateGas" -> %{"jsonrpc" => "2.0", "id" => 1, "result" => "0x5208"}
        _ -> %{"jsonrpc" => "2.0", "id" => 1, "result" => "0x0"}
      end
      conn |> Plug.Conn.put_resp_content_type("application/json") |> Plug.Conn.send_resp(200, Jason.encode!(result))
    end)

    {:ok, result} = Estimator.estimate_gas(
      %{to: "0xabc", value: 1000},
      [rpc_url: "http://localhost", plug: {Req.Test, __MODULE__.GasEst}]
    )
    assert result.gas_estimate == 21_000
    assert result.gas_with_buffer == 25_200
  end

  # === MEV Protection ===

  test "assess low risk transaction" do
    risk = MevProtection.assess_mev_risk(%{to: "0xabc", value: 1000})
    assert risk.risk_level == :low
    assert risk.use_flashbots == false
  end

  test "assess high risk DEX swap" do
    risk = MevProtection.assess_mev_risk(%{
      to: "0xrouter", value: 2_000_000_000_000_000_000,
      data: "0x38ed1739"  # swapExactTokensForTokens
    })
    assert risk.risk_level == :high
    assert risk.use_flashbots
    assert :uniswap_swap in risk.risk_factors
    assert :high_value in risk.risk_factors
  end

  test "assess medium risk swap" do
    risk = MevProtection.assess_mev_risk(%{value: 100, data: "0x7ff36ab5"})
    assert risk.risk_level == :medium
    assert :uniswap_swap in risk.risk_factors
  end

  test "assess token approval risk" do
    risk = MevProtection.assess_mev_risk(%{data: "0x095ea7b3"})
    assert :token_approval in risk.risk_factors
  end

  test "flashbots protect URL" do
    assert MevProtection.protect_rpc_url() == "https://protect.flashbots.net"
  end

  test "send private tx with mock" do
    Req.Test.stub(__MODULE__.FB, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, Jason.encode!(%{"jsonrpc" => "2.0", "id" => 1, "result" => "0xhash"}))
    end)

    {:ok, result} = MevProtection.send_private_transaction("0xrawtx", plug: {Req.Test, __MODULE__.FB}, rpc_url: "http://localhost")
    assert result == "0xhash"
  end

  # === Unknown Action ===

  test "unknown action" do
    assert {:error, "Unknown action: foobar"} = OptimizeTransaction.handler(%{action: "foobar"}, [])
  end
end
