defmodule Lux.Prisms.YouTube.Live.TransitionBroadcast do
  @moduledoc """
  Safely transitions a YouTube live broadcast through the allowed lifecycle.
  """

  use Lux.Prism,
    name: "Transition YouTube Live Broadcast",
    description:
      "Transitions a broadcast with ready -> testing -> live -> complete safety checks",
    input_schema: %{
      type: :object,
      properties: %{
        access_token: %{type: :string},
        broadcast_id: %{type: :string},
        current_status: %{type: :string},
        target_status: %{type: :string}
      },
      required: ["access_token", "broadcast_id", "current_status", "target_status"]
    }

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.LiveWorkflow

  def handler(input, _context) do
    LiveWorkflow.transition_broadcast(
      Client.get(input, :broadcast_id),
      Client.get(input, :current_status),
      Client.get(input, :target_status),
      input
    )
  end
end
