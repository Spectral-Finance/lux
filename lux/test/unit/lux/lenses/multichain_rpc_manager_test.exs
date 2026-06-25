defmodule Lux.Lenses.MultiChain.RpcManagerTest do
  use ExUnit.Case, async: true

  alias Lux.Lenses.MultiChain.RpcManager

  describe "supported_chains/0" do
    test "returns at least 8 chain configurations" do
      chains = RpcManager.supported_chains()
      assert length(chains) >= 8
    end

    test "each chain has required fields" do
      chains = RpcManager.supported_chains()

      Enum.each(chains, fn chain ->
        assert is_integer(chain.id) and chain.id > 0
        assert is_binary(chain.name) and byte_size(chain.name) > 0
        assert is_binary(chain.rpc_url)
        assert is_binary(chain.api_url)
        assert is_binary(chain.explorer_url)
        assert is_binary(chain.native_currency)
        assert is_integer(chain.block_time_seconds)
        assert chain.enabled == true
      end)
    end

    test "includes all major EVM chains" do
      chains = RpcManager.supported_chains() |> Enum.map(& &1.id)
      assert 1 in chains
      assert 56 in chains
      assert 137 in chains
      assert 42161 in chains
      assert 10 in chains
      assert 43114 in chains
      assert 250 in chains
      assert 8453 in chains
    end
  end

  describe "get_chain/1" do
    test "returns chain config for known chain ID" do
      chain = RpcManager.get_chain(1)
      assert chain.name == "Ethereum"
      assert chain.native_currency == "ETH"
    end

    test "returns disabled config for unknown chain ID" do
      chain = RpcManager.get_chain(99999)
      assert chain.enabled == false
    end
  end

  describe "rpc_url/1" do
    test "returns correct RPC URL for Ethereum" do
      assert RpcManager.rpc_url(1) =~ "eth"
    end

    test "returns correct RPC URL for BSC" do
      assert RpcManager.rpc_url(56) =~ "bsc"
    end

    test "raises for unsupported chain" do
      assert_raise ArgumentError, fn -> RpcManager.rpc_url(99999) end
    end
  end

  describe "enabled_chain_ids/0" do
    test "returns list of enabled chain IDs" do
      ids = RpcManager.enabled_chain_ids()
      assert is_list(ids)
      assert 1 in ids
      assert 56 in ids
      assert 137 in ids
    end
  end

  describe "chain_count/0" do
    test "returns number of enabled chains" do
      count = RpcManager.chain_count()
      assert count >= 8
    end
  end

  describe "supported?/1" do
    test "returns true for supported chains" do
      assert RpcManager.supported?(1)
      assert RpcManager.supported?(56)
      assert RpcManager.supported?(137)
    end

    test "returns false for unsupported chains" do
      refute RpcManager.supported?(99999)
    end
  end

  describe "get_chains/1" do
    test "returns configs for multiple chain IDs" do
      chains = RpcManager.get_chains([1, 56, 137])
      assert length(chains) == 3

      chain_ids = Enum.map(chains, & &1.id)
      assert 1 in chain_ids
      assert 56 in chain_ids
      assert 137 in chain_ids
    end

    test "filters out unsupported chains" do
      chains = RpcManager.get_chains([1, 99999, 56])
      assert length(chains) == 2
    end
  end
end
