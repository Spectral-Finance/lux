defmodule Lux.ChainTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias Lux.Chain

  describe "get/1" do
    test "returns chain config for known chains" do
      chain = Chain.get(:ethereum)
      assert %Chain{} = chain
      assert chain.id == :ethereum
      assert chain.chain_id == 1
      assert chain.name == "Ethereum Mainnet"
      assert chain.native_currency == "ETH"
      assert chain.currency_decimals == 18
      assert chain.block_time_ms == 12_000
    end

    test "returns nil for unknown chains" do
      assert Chain.get(:unknown_chain) == nil
    end

    test "returns correct config for all supported chains" do
      assert %Chain{chain_id: 137, native_currency: "MATIC"} = Chain.get(:polygon)
      assert %Chain{chain_id: 56, native_currency: "BNB"} = Chain.get(:bsc)
      assert %Chain{chain_id: 42_161, native_currency: "ETH"} = Chain.get(:arbitrum)
      assert %Chain{chain_id: 10, native_currency: "ETH"} = Chain.get(:optimism)
      assert %Chain{chain_id: 8453, native_currency: "ETH"} = Chain.get(:base)
      assert %Chain{chain_id: 43_114, native_currency: "AVAX"} = Chain.get(:avalanche)
    end
  end

  describe "get!/1" do
    test "returns chain config for known chains" do
      assert %Chain{id: :ethereum} = Chain.get!(:ethereum)
    end

    test "raises for unknown chains" do
      assert_raise ArgumentError, ~r/Unknown chain/, fn ->
        Chain.get!(:unknown_chain)
      end
    end
  end

  describe "from_chain_id/1" do
    test "returns chain for known numeric IDs" do
      assert {:ok, %Chain{id: :ethereum}} = Chain.from_chain_id(1)
      assert {:ok, %Chain{id: :polygon}} = Chain.from_chain_id(137)
      assert {:ok, %Chain{id: :bsc}} = Chain.from_chain_id(56)
      assert {:ok, %Chain{id: :base}} = Chain.from_chain_id(8453)
    end

    test "returns error for unknown numeric IDs" do
      assert {:error, :unknown_chain} = Chain.from_chain_id(999_999)
    end
  end

  describe "all/0" do
    test "returns all supported chains" do
      chains = Chain.all()
      assert is_list(chains)
      assert length(chains) == 7
      assert Enum.all?(chains, &match?(%Chain{}, &1))
    end
  end

  describe "supported_ids/0" do
    test "returns all chain identifiers" do
      ids = Chain.supported_ids()
      assert :ethereum in ids
      assert :polygon in ids
      assert :bsc in ids
      assert :arbitrum in ids
      assert :optimism in ids
      assert :base in ids
      assert :avalanche in ids
    end
  end

  describe "supported?/1" do
    test "returns true for supported chains" do
      assert Chain.supported?(:ethereum)
      assert Chain.supported?(:polygon)
      assert Chain.supported?(:base)
    end

    test "returns false for unsupported chains" do
      refute Chain.supported?(:unknown)
      refute Chain.supported?(:solana)
    end
  end

  describe "etherscan_chain_id/1" do
    test "returns numeric chain ID for known chains" do
      assert Chain.etherscan_chain_id(:ethereum) == 1
      assert Chain.etherscan_chain_id(:polygon) == 137
      assert Chain.etherscan_chain_id(:bsc) == 56
    end

    test "returns nil for unknown chains" do
      assert Chain.etherscan_chain_id(:unknown) == nil
    end
  end

  describe "chain properties" do
    test "all chains have required fields" do
      for chain <- Chain.all() do
        assert chain.id != nil
        assert chain.chain_id > 0
        assert chain.name != nil
        assert chain.native_currency != nil
        assert chain.currency_decimals > 0
        assert chain.block_time_ms > 0
      end
    end

    test "all chains have unique chain IDs" do
      chain_ids = Enum.map(Chain.all(), & &1.chain_id)
      assert length(chain_ids) == length(Enum.uniq(chain_ids))
    end

    test "all chains have unique identifiers" do
      ids = Chain.supported_ids()
      assert length(ids) == length(Enum.uniq(ids))
    end
  end
end
