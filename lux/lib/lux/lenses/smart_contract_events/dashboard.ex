defmodule Lux.Lenses.SmartContractEvents.Dashboard do
  @moduledoc """
  Local lens returning a dashboard snapshot for the smart contract event monitor.
  """

  def view do
    Lux.Lens.new(
      name: "Smart Contract Event Monitor Dashboard",
      module_name: inspect(__MODULE__),
      description: "Summarizes subscriptions, cursors, pollers, and recent events.",
      url: "lux://smart-contract-events/dashboard",
      method: :get,
      schema: %{type: :object, properties: %{}}
    )
  end

  def focus(_input \\ %{}, _opts \\ []) do
    {:ok, Lux.EventMonitor.dashboard()}
  end
end
