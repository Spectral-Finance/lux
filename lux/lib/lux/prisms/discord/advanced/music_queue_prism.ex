defmodule Lux.Prisms.Discord.Advanced.MusicQueuePrism do
  @moduledoc """
  A prism that manages music playback queues, playlist tracks, skip, pause, and shuffle.
  """

  use Lux.Prism,
    name: "Discord Music Queue Prism",
    description: "Manages music playback queue, track advancement, pause, and shuffle",
    input_schema: %{
      type: :object,
      properties: %{
        action: %{
          type: :string,
          enum: ["add_track", "skip", "pause", "resume", "get_queue", "clear", "shuffle"],
          default: "get_queue"
        },
        guild_id: %{type: :string},
        track: %{
          type: :object,
          properties: %{
            title: %{type: :string},
            url: %{type: :string},
            duration_seconds: %{type: :integer},
            requested_by: %{type: :string}
          }
        }
      },
      required: ["guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        action: %{type: :string},
        guild_id: %{type: :string},
        result: %{type: [:object, :null]},
        status: %{type: :string}
      },
      required: ["action", "guild_id", "status"]
    }

  alias Lux.Discord.MusicQueue

  @impl true
  def handler(inputs, _context) do
    action = Map.get(inputs, "action") || Map.get(inputs, :action, "get_queue")
    guild_id = Map.get(inputs, "guild_id") || Map.get(inputs, :guild_id)

    case action do
      "add_track" ->
        raw_track = Map.get(inputs, "track") || Map.get(inputs, :track, %{})
        track = %{
          title: Map.get(raw_track, "title") || Map.get(raw_track, :title, "Lo-Fi Focus Beat"),
          url: Map.get(raw_track, "url") || Map.get(raw_track, :url, "https://music.example.com/track.mp3"),
          duration_seconds: Map.get(raw_track, "duration_seconds") || Map.get(raw_track, :duration_seconds, 180),
          requested_by: Map.get(raw_track, "requested_by") || Map.get(raw_track, :requested_by, "agent")
        }

        {:ok, res} = MusicQueue.add_track(guild_id, track)
        {:ok, %{action: "add_track", guild_id: guild_id, result: res, status: "queued"}}

      "skip" ->
        {:ok, next_track} = MusicQueue.skip(guild_id)
        {:ok, %{action: "skip", guild_id: guild_id, result: %{current_track: next_track}, status: "skipped"}}

      "pause" ->
        MusicQueue.pause(guild_id)
        {:ok, %{action: "pause", guild_id: guild_id, result: nil, status: "paused"}}

      "resume" ->
        MusicQueue.resume(guild_id)
        {:ok, %{action: "resume", guild_id: guild_id, result: nil, status: "playing"}}

      "shuffle" ->
        MusicQueue.shuffle(guild_id)
        {:ok, %{action: "shuffle", guild_id: guild_id, result: nil, status: "shuffled"}}

      "clear" ->
        MusicQueue.clear(guild_id)
        {:ok, %{action: "clear", guild_id: guild_id, result: nil, status: "cleared"}}

      _get_queue ->
        queue = MusicQueue.get_queue(guild_id)
        {:ok, %{action: "get_queue", guild_id: guild_id, result: queue, status: "ok"}}
    end
  end
end
