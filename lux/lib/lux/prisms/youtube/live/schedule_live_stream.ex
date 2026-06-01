defmodule Lux.Prisms.YouTube.Live.ScheduleLiveStream do
  @moduledoc """
  Creates a YouTube live broadcast, creates a stream, and binds them.
  """

  use Lux.Prism,
    name: "Schedule YouTube Live Stream",
    description: "Creates and binds a YouTube live broadcast and stream",
    input_schema: %{
      type: :object,
      properties: %{
        access_token: %{type: :string},
        title: %{type: :string},
        scheduled_start_time: %{type: :string},
        privacy_status: %{type: :string},
        ingestion_type: %{type: :string},
        resolution: %{type: :string},
        frame_rate: %{type: :string}
      },
      required: ["access_token", "title", "scheduled_start_time"]
    }

  alias Lux.Integrations.YouTube.LiveWorkflow

  def handler(input, _context), do: LiveWorkflow.schedule(input, input)
end
