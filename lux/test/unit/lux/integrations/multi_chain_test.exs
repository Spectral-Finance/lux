defmodule Lux.Integrations.MultiChainTest do
  @moduledoc """
  Test suite for the MultiChain module.
  """

  use UnitCase, async: true

  alias Lux.Integrations.MultiChain.ChainAdapter
  alias Lux.Integrations.MultiChain.Aggregator
  alias Lux.Integrations.MultiChain.Cache
  alias Lux.Integrations.MultiChain.{
    Ethereum,
    Polygon,
    Arbitrum,
    Optimism,
    Base,
    Bnb
  }

  @test_address "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"

  # --- Chain Adapter Behaviour ---

  describe "ChainAdapter behaviour" do
    test "all modules implement required callbacks" do
      modules = [Ethereum, Polygon, Arbitrum, Optimism, Base, Bnb]

      Enum.each(modules, fn module ->
        assert function_exported?(module, :chain_name, 0)
        assert function_exported?(module, :chain_id, 0)
        assert function_exported?(module, :native_currency, 0)
        assert function_exported?(module, :symbol, 0)
        assert function_exported?(module, :fetch_balance, 1)
        assert function_exported?(module, :fetch_block_number, 0)
        assert function_exported?(module, :fetch_gas_price, 0)
      end)
    end
  end

  # --- Chain Metadata ---

  describe "chain metadata" do
    test "Ethereum has correct metadata" do
      assert Ethereum.chain_name() == "Ethereum"
      assert Ethereum.chain_id() == "1"
      assert Ethereum.native_currency() == "ETH"
      assert Ethereum.symbol() == "ETH"
    end

    test "Polygon has correct metadata" do
      assert Polygon.chain_name() == "Polygon"
      assert Polygon.chain_id() == "137"
      assert Polygon.native_currency() == "MATIC"
      assert Polygon.symbol() == "MATIC"
    end

    test "Arbitrum has correct metadata" do
      assert Arbitrum.chain_name() == "Arbitrum One"
      assert Arbitrum.chain_id() == "42161"
      assert Arbitrum.native_currency() == "ETH"
      assert Arbitrum.symbol() == "ETH"
    end

    test "Optimism has correct metadata" do
      assert Optimism.chain_name() == "Optimism"
      assert Optimism.chain_id() == "10"
      assert Optimism.native_currency() == "ETH"
      assert Optimism.symbol() == "ETH"
    end

    test "Base has correct metadata" do
      assert Base.chain_name() == "Base"
      assert Base.chain_id() == "8453"
      assert Base.native_currency() == "ETH"
      assert Base.symbol() == "ETH"
    end

    test "BNB has correct metadata" do
      assert Bnb.chain_name() == "BNB Smart Chain"
      assert Bnb.chain_id() == "56"
      assert Bnb.native_currency() == "BNB"
      assert Bnb.symbol() == "BNB"
    end
  end

  # --- Wei Conversion ---

  describe "wei_to_native/1" do
    test "converts 0 wei to 0.0" do
      assert ChainAdapter.wei_to_native(0) == 0.0
    end

    test "converts 1 ether (10^18 wei) to 1.0" do
      assert ChainAdapter.wei_to_native(1_000_000_000_000_000_000) == 1.0
    end

    test "converts hex string to native" do
      hex = "0x" <> String.duplicate("0", 39) <> "1"
      result = ChainAdapter.wei_to_native(hex)
      assert is_float(result)
      assert result > 0
    end

    test "converts small amounts" do
      assert ChainAdapter.wei_to_native(1_000_000_000_000_000) == 0.001
    end
  end

  describe "native_to_wei/1" do
    test "converts 1.0 ETH to wei" do
      assert ChainAdapter.native_to_wei(1.0) == 1_000_000_000_000_000_000
    end

    test "converts 0.5 ETH to wei" do
      assert ChainAdapter.native_to_wei(0.5) == 500_000_000_000_000_000
    end
  end

  # --- Address Validation ---

  describe "validate_address/1" do
    test "valid address returns lowercase" do
      assert {:ok, result} = Ethereum.validate_address(@test_address)
      assert result == String.downcase(@test_address)
    end

    test "invalid address returns error" do
      assert {:error, _} = Ethereum.validate_address("not_an_address")
      assert {:error, _} = Ethereum.validate_address("0x123")
      assert {:error, _} = Ethereum.validate_address("")
    end
  end

  # --- Block Tag Conversion ---

  describe "block_to_hex/1" do
    test "latest tag" do
      assert Ethereum.block_to_hex("latest") == "latest"
    end

    test "pending tag" do
      assert Ethereum.block_to_hex("pending") == "pending"
    end

    test "integer block" do
      assert Ethereum.block_to_hex(12345) == "0x3039"
    end

    test "hex string passes through" do
      assert Ethereum.block_to_hex("0xabcd") == "0xabcd"
    end
  end

  # --- Aggregator ---

  describe "Aggregator" do
    test "supported_chains returns all 6 chains" do
      chains = Aggregator.supported_chains()
      assert length(chains) == 6
      assert :ethereum in chains
      assert :polygon in chains
      assert :arbitrum in chains
      assert :optimism in chains
      assert :base in chains
      assert :bnb in chains
    end

    test "chain_adapters returns module map" do
      adapters = Aggregator.chain_adapters()
      assert length(adapters) == 6
      assert Map.has_key?(adapters, :ethereum)
      assert Map.has_key?(adapters, :polygon)
    end

    test "rejects unsupported operation" do
      assert {:error, msg} = Aggregator.aggregate(%{
        addresses: [@test_address],
        operation: :unsupported
      })
      assert String.contains?(msg, "Unsupported operation")
    end

    test "rejects invalid input" do
      assert {:error, msg} = Aggregator.aggregate(%{})
      assert String.contains?(msg, "Invalid input")
    end

    test "fetch_for_chain block_number returns correct shape" do
      {:ok, data} = Aggregator.fetch_for_chain(Ethereum, [], :block_number, "latest")
      assert is_map(data)
      assert Map.has_key?(data, "block")
    end
  end

  # --- Cache ---

  describe "Cache" do
    setup do
      on_exit(fn -> Cache.flush() end)
    end

    test "initializes and stores values" do
      :ok = Cache.start_link()
      key = {:balance, :ethereum, @test_address}
      value = %{balance_wei: 1000, balance_native: 0.001}

      :ok = Cache.put(key, value, 5000)
      assert Cache.get(key) == {:ok, value}
    end

    test "returns miss for non-existent key" do
      :ok = Cache.start_link()
      key = {:balance, :ethereum, "0x0000000000000000000000000000000000000000"}
      assert Cache.get(key) == :miss
    end

    test "invalidates a single entry" do
      :ok = Cache.start_link()
      key = {:balance, :ethereum, @test_address}
      value = %{balance: 1.0}

      :ok = Cache.put(key, value)
      assert Cache.get(key) == {:ok, value}

      :ok = Cache.invalidate(key)
      assert Cache.get(key) == :miss
    end

    test "flushes all entries" do
      :ok = Cache.start_link()

      :ok = Cache.put({:balance, :ethereum, @test_address}, %{balance: 1.0})
      :ok = Cache.put({:balance, :polygon, @test_address}, %{balance: 2.0})

      assert Cache.size() >= 2
      count = Cache.flush()
      assert count >= 2
      assert Cache.size() == 0
    end

    test "clears entries for a specific chain" do
      :ok = Cache.start_link()

      :ok = Cache.put({:balance, :ethereum, @test_address}, %{balance: 1.0})
      :ok = Cache.put({:balance, :polygon, @test_address}, %{balance: 2.0})

      cleared = Cache.clear_chain(:ethereum)
      assert cleared >= 1

      assert Cache.get({:balance, :ethereum, @test_address}) == :miss
      assert Cache.get({:balance, :polygon, @test_address}) == {:ok, %{balance: 2.0}}
    end
  end
end
