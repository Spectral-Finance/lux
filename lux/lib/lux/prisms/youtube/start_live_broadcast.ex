defmodule Lux.Prisms.YouTube.StartLiveBroadcast do
  @moduledoc """
  Creates a YouTube Live Broadcast, a Stream, binds them together,
  and optionally transitions it to the 'testing' or 'live' state.
  """
  use Lux.Prism,
    name: "YouTube Start Live Broadcast",
    description: "Sets up a complete YouTube live stream by creating a broadcast, a stream, and binding them. Requires OAuth authentication.",
    input_schema: %{
      type: :object,
      properties: %{
        title: %{
          type: :string,
          description: "Title of the live broadcast."
        },
        description: %{
          type: :string,
          description: "Description of the live broadcast."
        },
        scheduled_start_time: %{
          type: :string,
          description: "ISO 8601 formatted datetime for when the broadcast is scheduled."
        },
        privacy_status: %{
          type: :string,
          description: "Privacy status: 'public', 'unlisted', or 'private'."
        },
        resolution: %{
          type: :string,
          description: "Target resolution (e.g., '1080p', '720p')."
        },
        dry_run: %{
          type: :boolean,
          description: "If true, simulates the API calls without mutation."
        }
      },
      required: ["title", "scheduled_start_time"]
    }

  alias Lux.Integrations.YouTube.Client
  alias Lux.Integrations.YouTube.LiveStream

  @impl true
  def handler(params, _context) do
    # Normalize string keys to atom keys internally for our helper functions
    params_atoms =
      params
      |> Enum.map(fn {k, v} -> {if(is_binary(k), do: String.to_atom(k), else: k), v} end)
      |> Enum.into(%{})

    config = %Client.Config{
      access_token: Application.get_env(:lux, :api_keys)[:youtube_access_token],
      dry_run: Map.get(params_atoms, :dry_run, true)
    }

    with {:ok, broadcast_resp} <- LiveStream.create_broadcast(params_atoms, config),
         # Check if dry_run returned
         {:dry_check, false} <- {:dry_check, Map.get(broadcast_resp, :dry_run, false)},
         broadcast_id = get_in(broadcast_resp, ["id"]),
         {:ok, stream_resp} <- LiveStream.create_stream(params_atoms, config),
         stream_id = get_in(stream_resp, ["id"]),
         {:ok, bind_resp} <- LiveStream.bind_broadcast(broadcast_id, stream_id, config) do
      {:ok, %{
        broadcast_id: broadcast_id,
        stream_id: stream_id,
        status: "bound",
        bind_response: bind_resp
      }}
    else
      {:dry_check, true} ->
        {:ok, %{
          dry_run: true,
          message: "Would have created broadcast, created stream, and bound them."
        }}
      error ->
        error
    end
  end
end
