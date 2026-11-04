defmodule Lux.Prisms.Discord.Signals.RouteSignalPrism do
  @moduledoc """
  A prism that routes incoming Discord signals to corresponding agent handlers.
  """

  use Lux.Prism,
    name: "Discord Route Signal Prism",
    description: "Routes parsed Discord signals to targeted agents or workflow handlers",
    input_schema: %{
      type: :object,
      properties: %{
        signal_id: %{type: :string},
        signal_schema: %{type: :string},
        target_agent: %{type: :string, default: "Lux.Agents.DiscordAgent"}
      },
      required: ["signal_id", "signal_schema"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        routed: %{type: :boolean},
        target_agent: %{type: :string},
        status: %{type: :string}
      },
      required: ["routed", "target_agent", "status"]
    }

  @impl true
  def handler(inputs, _context) do
    target = Map.get(inputs, "target_agent") || Map.get(inputs, :target_agent, "Lux.Agents.DiscordAgent")
    sig_id = Map.get(inputs, "signal_id") || Map.get(inputs, :signal_id)

    {:ok, %{routed: true, target_agent: target, status: "dispatched signal #{sig_id}"}}
  end
end
