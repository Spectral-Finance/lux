defmodule Lux.Integrations.Web3.ContractEventMonitorTest do
  use ExUnit.Case, async: true
  alias Lux.Integrations.Web3.ContractEventMonitor

  test "processes valid payload and computes efficiency score" do
    assert {:error, :empty_params} = Web3.ContractEventMonitor.process(%{})
    assert {:ok, %{verified: true, issue: 75}} = Web3.ContractEventMonitor.process(%{active: true})
    assert {:ok, 95.0} = Web3.ContractEventMonitor.compute_efficiency_score(100, 100, 500)
  end
end
