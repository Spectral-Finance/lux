defmodule Lux.Lenses.SmartContractEvents.ReplayEvents do
  @moduledoc """
  Local lens for replaying stored smart contract events.
  """

  def view do
    Lux.Lens.new(
      name: "Replay Smart Contract Events",
      module_name: inspect(__MODULE__),
      description: "Retrieves stored events by subscription, block range, and limit.",
      url: "lux://smart-contract-events/replay",
      method: :get,
      schema: %{
        type: :object,
        properties: %{
          subscription_id: %{type: :string},
          from_block: %{type: :integer},
          to_block: %{type: :integer},
          limit: %{type: :integer, default: 100}
        }
      }
    )
  end

  def focus(input \\ %{}, _opts \\ []) do
    Lux.EventMonitor.replay_events(input)
  end
end
