defmodule Lux.Lenses.YouTube.CheckStreamHealth do
  @moduledoc """
  Fetches the health status of a YouTube Live Stream.
  """
  @behaviour Lux.Lens

  def view do
    Lux.Lens.new(
      name: "YouTube Check Stream Health",
      description: "Gets the health status of a specific live stream. Useful for determining if a stream is ready to transition to live.",
      schema: %{
        type: :object,
        properties: %{
          stream_id: %{
            type: :string,
            description: "The ID of the stream to check."
          }
        },
        required: ["stream_id"]
      }
    )
  end

  alias Lux.Integrations.YouTube.LiveStream
  alias Lux.Integrations.YouTube.Client

  def focus(params, _context) do
    stream_id = Map.get(params, "stream_id") || Map.get(params, :stream_id)

    config = Client.default_config()

    case LiveStream.get_stream_health(stream_id, config) do
      {:ok, health} -> {:ok, %{health_status: health}}
      error -> error
    end
  end
end
