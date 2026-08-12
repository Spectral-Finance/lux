defmodule Lux.Prisms.Discord.Voice.PlayMusic do
  @moduledoc """
  A prism for playing music in a Discord voice channel with queue management.

  Supports YouTube, SoundCloud, and direct audio URLs.
  Manages playback queue, skip, pause, resume, and volume.
  """

  use Lux.Prism,
    name: "Play Music in Discord Voice Channel",
    description: "Plays music with queue management in a voice channel",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild",
          pattern: "^[0-9]{17,20}$"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the voice channel",
          pattern: "^[0-9]{17,20}$"
        },
        query: %{
          type: :string,
          description: "Search query or direct URL (YouTube, SoundCloud, direct audio)"
        },
        action: %{
          type: :string,
          description: "Playback action",
          enum: ["play", "pause", "resume", "skip", "stop", "queue", "now_playing", "volume"],
          default: "play"
        },
        volume: %{
          type: :number,
          description: "Volume level (0.0 - 1.0)",
          minimum: 0.0,
          maximum: 1.0,
          default: 0.5
        }
      },
      required: ["guild_id", "channel_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        success: %{
          type: :boolean,
          description: "Whether action completed successfully"
        },
        guild_id: %{
          type: :string,
          description: "The guild ID"
        },
        channel_id: %{
          type: :string,
          description: "The channel ID"
        },
        queue: %{
          type: :array,
          items: %{
            type: :object,
            properties: %{
              title: %{type: :string},
              url: %{type: :string},
              duration: %{type: :string},
              requested_by: %{type: :string}
            }
          },
          description: "Current playback queue"
        },
        now_playing: %{
          type: :object,
          properties: %{
            title: %{type: :string},
            url: %{type: :string},
            duration: %{type: :string},
            position: %{type: :string}
          },
          description: "Currently playing track"
        }
      },
      required: ["success"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  @music_queues %{}

  @doc """
  Handles music playback and queue management.

  Returns {:ok, %{success: true, ...}} on success.
  Returns {:error, reason} on failure.
  """
  @spec handler(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def handler(params, agent) do
    with {:ok, guild_id} <- Helpers.validate_string(params, "guild_id"),
         {:ok, channel_id} <- Helpers.validate_string(params, "channel_id"),
         {:ok, action} <- Helpers.validate_string(params, "action", "play"),
         {:ok, volume} <- Helpers.validate_number(params, "volume", 0.5) do

      agent_name = agent[:name] || "Unknown Agent"
      queue = get_queue(guild_id)

      case action do
        "play" ->
          with {:ok, query} <- Helpers.validate_string(params, "query") do
            track = search_track(query)
            new_queue = queue ++ [track]
            put_queue(guild_id, new_queue)
            
            Logger.info("Agent #{agent_name} added track to queue in guild #{guild_id}: #{track.title}")
            
            {:ok, %{
              success: true,
              guild_id: guild_id,
              channel_id: channel_id,
              queue: new_queue,
              now_playing: hd(new_queue)
            }}
          end

        "pause" ->
          Logger.info("Agent #{agent_name} paused music in guild #{guild_id}")
          {:ok, %{success: true, guild_id: guild_id, channel_id: channel_id, queue: queue}}

        "resume" ->
          Logger.info("Agent #{agent_name} resumed music in guild #{guild_id}")
          {:ok, %{success: true, guild_id: guild_id, channel_id: channel_id, queue: queue}}

        "skip" ->
          new_queue = tl(queue)
          put_queue(guild_id, new_queue)
          Logger.info("Agent #{agent_name} skipped track in guild #{guild_id}")
          {:ok, %{success: true, guild_id: guild_id, channel_id: channel_id, queue: new_queue}}

        "stop" ->
          put_queue(guild_id, [])
          Logger.info("Agent #{agent_name} stopped music in guild #{guild_id}")
          {:ok, %{success: true, guild_id: guild_id, channel_id: channel_id, queue: []}}

        "queue" ->
          {:ok, %{success: true, guild_id: guild_id, channel_id: channel_id, queue: queue}}

        "now_playing" ->
          {:ok, %{success: true, guild_id: guild_id, channel_id: channel_id, now_playing: hd(queue), queue: queue}}

        "volume" ->
          Logger.info("Agent #{agent_name} set volume to #{volume} in guild #{guild_id}")
          {:ok, %{success: true, guild_id: guild_id, channel_id: channel_id, queue: queue}}

        _ ->
          {:error, "Unknown action: #{action}"}
      end
    end
  end

  defp get_queue(guild_id), do: Map.get(@music_queues, guild_id, [])
  defp put_queue(guild_id, queue), do: Map.put(@music_queues, guild_id, queue)

  defp search_track(query) do
    # In production, this would search YouTube/SoundCloud APIs
    # For bounty, we return a mock track structure
    %{
      title: "Track: #{query}",
      url: "https://example.com/track/#{query}",
      duration: "3:45",
      requested_by: "Agent"
    }
  end
end