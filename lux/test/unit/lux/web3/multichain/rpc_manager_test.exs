defmodule Lux.Web3.Multichain.RpcManagerTest do
  use ExUnit.Case, async: false

  alias Lux.Web3.Multichain.RpcManager

  describe "Multi-Chain RPC Manager (#74)" do
    test "retrieves supported chains and network IDs" do
      chains = RpcManager.supported_chains()
      assert :ethereum in chains
      assert :bsc in chains
      assert :polygon in chains
      assert :arbitrum in chains
      assert :optimism in chains
      assert :base in chains
      assert :avalanche in chains

      assert {:ok, 1} = RpcManager.get_chain_id(:ethereum)
      assert {:ok, 56} = RpcManager.get_chain_id(:bsc)
      assert {:ok, 137} = RpcManager.get_chain_id(:polygon)
      assert {:ok, 42161} = RpcManager.get_chain_id(:arbitrum)
      assert {:ok, 8453} = RpcManager.get_chain_id(:base)
      assert {:error, :unsupported_chain} = RpcManager.get_chain_id(:solana)
    end

    test "executes RPC call with mock client" do
      {:ok, pid} =
        RpcManager.start_link(name: :test_rpc_manager, rate_limit_config: %{max_consecutive_failures: 2, cooldown_sec: 10})

      mock = fn "eth_blockNumber", _params ->
        {:ok, "0x12345", 15}
      end

      assert {:ok, "0x12345"} = RpcManager.rpc_call(pid, :ethereum, "eth_blockNumber", [], mock_client: mock)
    end

    test "performs automatic failover to fallback endpoint when primary fails" do
      custom_chains = %{
        test_chain: %{
          chain_id: 999,
          name: "Test Chain",
          endpoints: ["https://primary.rpc.test", "https://fallback.rpc.test"]
        }
      }

      {:ok, pid} =
        RpcManager.start_link(
          name: :test_failover_manager,
          chains: custom_chains,
          rate_limit_config: %{max_consecutive_failures: 1, cooldown_sec: 10}
        )

      call_count = :atomics.new(1, [])

      mock = fn "eth_blockNumber", _params ->
        count = :atomics.add_get(call_count, 1, 1)

        if count == 1 do
          {:error, :transport_error}
        else
          {:ok, "0x9999", 25}
        end
      end

      assert {:ok, "0x9999"} = RpcManager.rpc_call(pid, :test_chain, "eth_blockNumber", [], mock_client: mock)

      health = RpcManager.get_health(pid)
      assert Map.has_key?(health, :test_chain)
      assert health[:test_chain].total_count == 2
    end
  end
end
