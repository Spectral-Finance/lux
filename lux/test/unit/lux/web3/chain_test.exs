defmodule Lux.Web3.ChainTest do
  use UnitCase, async: true

  alias Lux.Web3.Chain

  doctest Lux.Web3.Chain

  describe "all/0 and supported_chain_ids/0" do
    test "returns every supported chain sorted by ascending chain id" do
      chains = Chain.all()
      ids = Enum.map(chains, & &1.chain_id)

      assert ids == Enum.sort(ids)
      assert length(chains) >= 7
      assert Enum.all?(chains, &is_binary(&1.name))
      assert Enum.all?(chains, &is_binary(&1.native_currency))
    end

    test "supported_chain_ids/0 is sorted and deduplicated" do
      ids = Chain.supported_chain_ids()

      assert ids == Enum.sort(ids)
      assert ids == Enum.uniq(ids)
      assert 1 in ids
      assert 137 in ids
    end
  end

  describe "get/1" do
    test "returns a chain for a supported integer id" do
      assert {:ok, %{chain_id: 1, name: "ethereum", native_currency: "ETH"}} = Chain.get(1)
    end

    test "accepts numeric strings with surrounding whitespace" do
      assert {:ok, %{name: "polygon"}} = Chain.get(" 137 ")
    end

    test "null input is rejected with a typed error" do
      assert {:error, :invalid_chain_id} = Chain.get(nil)
    end

    test "empty and whitespace-only strings are rejected" do
      assert {:error, :invalid_chain_id} = Chain.get("")
      assert {:error, :invalid_chain_id} = Chain.get("   ")
    end

    test "negative and non-integer boundary values are rejected" do
      assert {:error, :invalid_chain_id} = Chain.get(-1)
      assert {:error, :invalid_chain_id} = Chain.get(1.5)
    end

    test "chain id 0 is a valid non-negative id but unsupported" do
      assert {:error, :unsupported_chain} = Chain.get(0)
    end

    test "unknown chain ids return :unsupported_chain" do
      assert {:error, :unsupported_chain} = Chain.get(424_242)
    end

    test "non-numeric strings are rejected" do
      assert {:error, :invalid_chain_id} = Chain.get("abc")
    end
  end

  describe "get!/1" do
    test "returns the chain for a supported id" do
      assert %{name: "base"} = Chain.get!(8453)
    end

    test "raises ArgumentError for an unsupported chain" do
      assert_raise ArgumentError, fn -> Chain.get!(424_242) end
    end
  end

  describe "supported?/1" do
    test "is true only for supported integer ids" do
      assert Chain.supported?(1)
      refute Chain.supported?(424_242)
      refute Chain.supported?("1")
      refute Chain.supported?(nil)
    end
  end

  describe "find_by_name/1 and helpers" do
    test "matches names case-insensitively and trims whitespace" do
      assert {:ok, %{chain_id: 1}} = Chain.find_by_name("  ETHEREUM ")
    end

    test "null and empty names are rejected" do
      assert {:error, :unknown_chain} = Chain.find_by_name(nil)
      assert {:error, :unknown_chain} = Chain.find_by_name("")
    end

    test "name/1 and native_currency/1 delegate to the registry" do
      assert {:ok, "ethereum"} = Chain.name(1)
      assert {:ok, "POL"} = Chain.native_currency(137)
      assert {:error, :unsupported_chain} = Chain.name(424_242)
      assert {:error, :invalid_chain_id} = Chain.native_currency(nil)
    end
  end
end
