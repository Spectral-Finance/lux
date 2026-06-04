defmodule Lux.Web3.MultiChainTest do
  use ExUnit.Case, async: true
  import Lux.Web3.MultiChain

  describe "hex_to_int/1" do
    test "parses '0x0' as zero" do
      assert hex_to_int("0x0") == 0
    end

    test "parses '0x1234' as 4660" do
      assert hex_to_int("0x1234") == 4660
    end

    test "parses large hex values" do
      # 1 ETH in wei
      assert hex_to_int("0x0de0b6b3a7640000") == 1_000_000_000_000_000_000
    end

    test "parses without 0x prefix" do
      assert hex_to_int("1234") == 4660
    end
  end

  describe "resolve_chain/1" do
    test "returns info for known chain" do
      assert {:ok, info} = resolve_chain(:ethereum)
      assert info.name == "Ethereum"
      assert info.rpc == "https://eth.llamarpc.com"
    end

    test "returns error for unknown chain" do
      assert {:error, {:unsupported_chain, :solana}} = resolve_chain(:solana)
    end
  end

  describe "chain_info/1" do
    test "returns info for known chain" do
      assert %{name: "Polygon"} = chain_info(:polygon)
    end

    test "returns nil for unknown chain" do
      assert chain_info(:solana) == nil
    end
  end

  describe "balance/2" do
    test "returns error for unsupported chain without crashing" do
      assert {:error, {:unsupported_chain, :solana}} = balance("0x1234", :solana)
    end
  end

  describe "multi_chain_balance/1" do
    test "returns a map with all chains and never crashes" do
      # Even if RPC calls fail, the function should return {:ok, map}
      # with error entries for failed chains
      result = multi_chain_balance("0xdead000000000000000000000000000000000000")
      assert match?({:ok, %{ethereum: _, polygon: _, arbitrum: _, optimism: _, base: _}}, result)
    end
  end

  describe "token_balance/3" do
    test "returns error for unsupported chain without crashing" do
      assert {:error, {:unsupported_chain, :solana}} = token_balance("0xtoken", "0xaddr", :solana)
    end

    test "does not crash on missing chain key in @chains" do
      assert {:error, {:unsupported_chain, :does_not_exist}} = token_balance("0xtoken", "0xaddr", :does_not_exist)
    end
  end
end
