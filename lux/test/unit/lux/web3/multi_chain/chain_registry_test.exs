defmodule Lux.Web3.MultiChain.ChainRegistryTest do
  use UnitAPICase, async: true

  alias Lux.Web3.MultiChain.ChainRegistry

  describe "fetch/1" do
    test "fetches built-in chains by key and chain id" do
      assert {:ok, ethereum} = ChainRegistry.fetch(:ethereum)
      assert ethereum.chain_id == 1
      assert ethereum.key == :ethereum

      assert {:ok, polygon} = ChainRegistry.fetch("polygon")
      assert polygon.chain_id == 137

      assert {:ok, base} = ChainRegistry.fetch(8453)
      assert base.key == :base
    end

    test "rejects unknown chains" do
      assert ChainRegistry.fetch("unknown-chain") == {:error, :unknown_chain}
      assert ChainRegistry.fetch(999_999) == {:error, :unknown_chain}
    end
  end

  describe "rpc_url/2" do
    test "resolves configured rpc urls" do
      assert ChainRegistry.rpc_url(:ethereum, %{
               rpc_urls: %{ethereum: "https://eth.example"}
             }) == {:ok, "https://eth.example"}
    end

    test "reports missing rpc urls" do
      assert ChainRegistry.rpc_url(:ethereum, %{rpc_urls: %{}}) == {
               :error,
               {:missing_rpc_url, :ethereum}
             }
    end
  end
end
