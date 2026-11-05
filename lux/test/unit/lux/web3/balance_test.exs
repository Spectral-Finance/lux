defmodule Lux.Web3.BalanceTest.StaticProvider do
  @moduledoc false
  @behaviour Lux.Web3.Balance.Provider

  @impl true
  def balance(_address, chain_id, _opts), do: {:ok, chain_id * 1_000}
end

defmodule Lux.Web3.BalanceTest.FlakyProvider do
  @moduledoc false
  @behaviour Lux.Web3.Balance.Provider

  @impl true
  def balance(_address, 10, _opts), do: {:error, :boom}
  def balance(_address, chain_id, _opts), do: {:ok, chain_id}
end

defmodule Lux.Web3.BalanceTest do
  use UnitCase, async: true

  alias Lux.Web3.Balance
  alias Lux.Web3.BalanceTest.FlakyProvider
  alias Lux.Web3.BalanceTest.StaticProvider

  doctest Lux.Web3.Balance

  @address "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1"

  setup do
    tracker = start_supervised!(Balance)
    %{tracker: tracker}
  end

  describe "put/4, get/3, list/2 and total/2 (happy path)" do
    test "stores and retrieves balances per chain", %{tracker: tracker} do
      assert {:ok, %{address: @address, chain_id: 1, wei: 1_500_000_000_000_000_000}} =
               Balance.put(tracker, @address, 1, 1_500_000_000_000_000_000)

      assert {:ok, %{wei: 1_500_000_000_000_000_000}} = Balance.get(tracker, @address, 1)
    end

    test "lists balances sorted by chain id", %{tracker: tracker} do
      Balance.put(tracker, @address, 137, 300)
      Balance.put(tracker, @address, 1, 100)
      Balance.put(tracker, @address, 10, 200)

      assert {:ok, balances} = Balance.list(tracker, @address)
      assert Enum.map(balances, & &1.chain_id) == [1, 10, 137]
      assert Enum.map(balances, & &1.wei) == [100, 200, 300]
    end

    test "totals balances across chains", %{tracker: tracker} do
      Balance.put(tracker, @address, 1, 100)
      Balance.put(tracker, @address, 10, 200)

      assert {:ok, 300} = Balance.total(tracker, @address)
    end
  end

  describe "refresh/4 (happy path)" do
    test "refreshes balances through a provider and stores them", %{tracker: tracker} do
      assert {:ok, balances} =
               Balance.refresh(tracker, @address, [1, 10], provider: StaticProvider)

      assert Enum.map(balances, &{&1.chain_id, &1.wei}) == [{1, 1_000}, {10, 10_000}]

      assert {:ok, %{wei: 10_000}} = Balance.get(tracker, @address, 10)
    end

    test "skips provider failures without corrupting state", %{tracker: tracker} do
      assert {:ok, balances} =
               Balance.refresh(tracker, @address, [1, 10], provider: FlakyProvider)

      assert Enum.map(balances, & &1.chain_id) == [1]
      assert {:error, :not_found} = Balance.get(tracker, @address, 10)
    end
  end

  describe "null and empty input" do
    test "rejects a null or malformed address", %{tracker: tracker} do
      assert {:error, :invalid_address} = Balance.put(tracker, nil, 1, 1)
      assert {:error, :invalid_address} = Balance.put(tracker, "", 1, 1)
      assert {:error, :invalid_address} = Balance.put(tracker, "not-an-address", 1, 1)
      assert {:error, :invalid_address} = Balance.get(tracker, nil, 1)
      assert {:error, :invalid_address} = Balance.list(tracker, nil)
      assert {:error, :invalid_address} = Balance.total(tracker, "")
    end

    test "rejects a missing provider and invalid chain list on refresh", %{tracker: tracker} do
      assert {:error, :missing_provider} = Balance.refresh(tracker, @address, [1])
      assert {:error, :missing_provider} = Balance.refresh(tracker, @address, [1], provider: nil)

      assert {:error, :invalid_chain_ids} =
               Balance.refresh(tracker, @address, "1", provider: StaticProvider)
    end
  end

  describe "boundaries" do
    test "accepts a zero balance at the lower bound", %{tracker: tracker} do
      assert {:ok, %{wei: 0}} = Balance.put(tracker, @address, 1, 0)
      assert {:ok, 0} = Balance.total(tracker, @address)
    end

    test "an unknown (address, chain) pair is not found", %{tracker: tracker} do
      assert {:error, :not_found} = Balance.get(tracker, @address, 1)
    end

    test "format/3 renders whole and fractional amounts", %{tracker: _tracker} do
      assert Balance.format(0) == "0 ETH"
      assert Balance.format(1) == "0.000000000000000001 ETH"
      assert Balance.format(1_500_000_000_000_000_000) == "1.5 ETH"
      assert Balance.format(1_000_000, "USDC", 6) == "1 USDC"
    end

    test "to_wei/2 scales by the requested decimals" do
      assert Balance.to_wei(0) == 0
      assert Balance.to_wei(1) == 1_000_000_000_000_000_000
      assert Balance.to_wei(3, 6) == 3_000_000
    end
  end

  describe "negative cases" do
    test "rejects a negative balance", %{tracker: tracker} do
      assert {:error, :invalid_amount} = Balance.put(tracker, @address, 1, -1)
    end

    test "rejects an unsupported chain", %{tracker: tracker} do
      assert {:error, :unsupported_chain} = Balance.put(tracker, @address, 424_242, 1)
      assert {:error, :invalid_chain_id} = Balance.put(tracker, @address, nil, 1)
    end
  end

  describe "concurrency" do
    test "concurrent writes keep the aggregate consistent", %{tracker: tracker} do
      chain_ids = [1, 10, 56, 137, 8453, 42_161, 43_114]

      results =
        chain_ids
        |> Task.async_stream(fn chain_id -> Balance.put(tracker, @address, chain_id, 1_000) end)
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.all?(results, &match?({:ok, _}, &1))
      assert {:ok, 7_000} = Balance.total(tracker, @address)
      assert {:ok, balances} = Balance.list(tracker, @address)
      assert length(balances) == 7
    end
  end
end
