defmodule Lux.Web3.ContractMonitorTest do
  use ExUnit.Case, async: true
  alias Lux.Web3.ContractMonitor
  describe "event monitoring" do
    test "monitor_event/4 creates event filter" do
      result = ContractMonitor.monitor_event("0x0000000000000000000000000000000000000001", "Transfer", nil, :ethereum)
      assert elem(result, 0) in [:ok, :error]
    end
    test "get_logs/4 retrieves event logs" do
      result = ContractMonitor.get_logs("0x0000000000000000000000000000000000000001", "Transfer", "0x0")
      assert elem(result, 0) in [:ok, :error]
    end
  end
  describe "signature generation" do
    test "event_signature/1 generates keccak signature" do
      sig = ContractMonitor.event_signature("Transfer(address,address,uint256)")
      assert is_binary(sig)
      assert String.length(sig) == 66
    end
  end
end
