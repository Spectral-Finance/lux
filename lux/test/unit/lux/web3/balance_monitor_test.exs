defmodule Lux.Web3.BalanceMonitorTest do
  use ExUnit.Case, async: false

  alias Lux.Web3.BalanceMonitor

  setup do
    # Start a fresh BalanceMonitor for each test
    case GenServer.whereis(BalanceMonitor) do
      nil ->
        {:ok, _pid} = BalanceMonitor.start_link(poll_interval: 60_000)
      _pid ->
        :ok
    end

    :ok
  end

  describe "watch/2 and unwatch/1" do
    test "can register and deregister a wallet address" do
      address = "0x1234567890abcdef1234567890abcdef12345678"
      assert :ok = BalanceMonitor.watch(address, [1, 137])
      assert :ok = BalanceMonitor.unwatch(address)
    end
  end

  describe "get_balance/2" do
    test "returns not_found for unwatched addresses" do
      assert {:error, :not_found} = BalanceMonitor.get_balance("0xnope", 1)
    end
  end

  describe "get_all_balances/1" do
    test "returns not_found for unwatched addresses" do
      assert {:error, :not_found} = BalanceMonitor.get_all_balances("0xnope")
    end
  end
end
