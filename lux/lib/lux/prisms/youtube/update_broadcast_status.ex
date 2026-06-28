defmodule Lux.Prisms.YouTube.UpdateBroadcastStatus do
  @moduledoc """
  Transitions a YouTube Live Broadcast status (e.g. testing -> live).
  """
  use Lux.Prism,
    name: "YouTube Update Broadcast Status",
    description: "Transitions the status of a broadcast (e.g., to 'testing', 'live', or 'complete').",
    input_schema: %{
      type: :object,
      properties: %{
        broadcast_id: %{
          type: :string,
          description: "The ID of the broadcast."
        },
        status: %{
          type: :string,
          description: "The status to transition to: 'testing', 'live', or 'complete'."
        },
        dry_run: %{
          type: :boolean,
          description: "If true, simulates the API calls without mutation."
        }
      },
      required: ["broadcast_id", "status"]
    }

  alias Lux.Integrations.YouTube.LiveStream
  alias Lux.Integrations.YouTube.Client

  @impl true
  def handler(params, _context) do
    broadcast_id = Map.get(params, "broadcast_id") || Map.get(params, :broadcast_id)
    status = Map.get(params, "status") || Map.get(params, :status)
    dry_run = Map.get_lazy(params, "dry_run", fn -> Map.get(params, :dry_run, true) end)

    config = %Client.Config{
      access_token: Application.get_env(:lux, :api_keys)[:youtube_access_token],
      dry_run: dry_run
    }

    LiveStream.transition_broadcast(broadcast_id, status, config)
  end
end
