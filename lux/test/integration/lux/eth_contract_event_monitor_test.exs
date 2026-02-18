defmodule Lux.Test.Integration.Lux.EthContractEventMonitorTest do
  import ExUnit.Case, async: true
  alias Lux.Prisms.EthContractEventMonitorPrism
  use EthContractEventMonitorPrism

  setup_all do
    EthContractEventMonitorPrism.start_link()
    :ok
  end

  test "subscribe to event" do
    contract_address = "0x1234567890abcdef"
    event_name = "Transfer"

    assert :ok == EthContractEventMonitorPrism.subscribe_to_event(contract_address, event_name)
    state = EthContractEventMonitorPrism.handle_call({:subscribe, contract_address, event_name}, nil, %{})
    assert %{contract_address => event_name} = state
  end

  test "unsubscribe from event" do
    contract_address = "0x1234567890abcdef"
    event_name = "Transfer"

    EthContractEventMonitorPrism.subscribe_to_event(contract_address, event_name)
    assert :ok == EthContractEventMonitorPrism.unsubscribe_from_event(contract_address, event_name)
    state = EthContractEventMonitorPrism.handle_call({:unsubscribe, contract_address, event_name}, nil, %{})
    refute Map.has_key?(state, {contract_address, event_name})
  end
end