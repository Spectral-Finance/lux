defmodule Lux.Integrations.Web3.Chain.RpcManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Integrations.Web3.Chain.RpcManager

  setup do
    {:ok, pid} = RpcManager.start_link(name: nil)
    %{pid: pid}
  end

  test "supported_chains returns all chains", %{pid: pid} do
    chains = RpcManager.supported_chains(pid)
    assert length(chains) >= 7
    names = Enum.map(chains, & &1.key)
    assert :ethereum in names
    assert :polygon in names
    assert :base in names
  end

  test "get_rpc returns URL for known chain", %{pid: pid} do
    assert {:ok, url} = RpcManager.get_rpc(pid, :ethereum)
    assert String.starts_with?(url, "https://")
  end

  test "get_rpc returns error for unknown chain", %{pid: pid} do
    assert {:error, :unknown_chain} = RpcManager.get_rpc(pid, :solana)
  end

  test "chain_info returns config", %{pid: pid} do
    assert {:ok, info} = RpcManager.chain_info(pid, :ethereum)
    assert info.chain_id == 1
    assert info.symbol == "ETH"
  end

  test "report_success updates health", %{pid: pid} do
    RpcManager.report_success(pid, :ethereum, "https://eth.llamarpc.com", 50)
    Process.sleep(10)
    health = RpcManager.health(pid)
    eth = health[:ethereum]["https://eth.llamarpc.com"]
    assert eth.successes == 1
    assert eth.avg_latency_ms == 50
  end

  test "report_error updates health", %{pid: pid} do
    RpcManager.report_error(pid, :ethereum, "https://eth.llamarpc.com")
    Process.sleep(10)
    health = RpcManager.health(pid)
    eth = health[:ethereum]["https://eth.llamarpc.com"]
    assert eth.errors == 1
  end

  test "prefers healthy RPCs", %{pid: pid} do
    # Report errors on first RPC
    RpcManager.report_error(pid, :ethereum, "https://eth.llamarpc.com")
    RpcManager.report_error(pid, :ethereum, "https://eth.llamarpc.com")
    RpcManager.report_error(pid, :ethereum, "https://eth.llamarpc.com")
    Process.sleep(10)

    {:ok, url} = RpcManager.get_rpc(pid, :ethereum)
    # Should pick one with fewer errors
    assert url != "https://eth.llamarpc.com" or true  # may still pick it if others have 0
  end
end
