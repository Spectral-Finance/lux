defmodule Lux.Prisms.Discord.Channels.MuteChannel do
  @moduledoc """
  A prism for muting notifications from a Discord channel.
  Supports both temporary and indefinite muting.

  ## Examples
      # Mute channel for 1 hour (3600 seconds)
      iex> MuteChannel.handler(%{
      ...>   channel_id: "123456789",
      ...>   guild_id: "987654321",
      ...>   duration: 3600
      ...> }, %{name: "Agent"})
      {:ok, %{muted: true, channel_id: "123456789", guild_id: "987654321", duration: 3600}}

      # Mute channel indefinitely
      iex> MuteChannel.handler(%{
      ...>   channel_id: "123456789",
      ...>   guild_id: "987654321",
      ...>   duration: nil
      ...> }, %{name: "Agent"})
      {:ok, %{muted: true, channel_id: "123456789", guild_id: "987654321", duration: nil}}
  """

  use Lux.Prism,
    name: "Mute Discord Channel",
    description: "Mutes notifications for a Discord channel for a specified duration",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to mute",
          pattern: "^[0-9]{17,20}$"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild containing the channel",
          pattern: "^[0-9]{17,20}$"
        },
        duration: %{
          type: [:integer, :null],
          description: "Duration to mute the channel for in seconds. Use nil for indefinite muting",
          minimum: 0
        }
      },
      required: ["channel_id", "guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        muted: %{
          type: :boolean,
          description: "Whether the channel was successfully muted"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the muted channel"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild containing the channel"
        },
        duration: %{
          type: [:integer, :null],
          description: "Duration the channel was muted for in seconds, or nil if muted indefinitely"
        }
      },
      required: ["muted"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to mute a Discord channel.

  Returns {:ok, %{muted: true, channel_id: channel_id, guild_id: guild_id, duration: duration}} on success.
  Returns {:error, {status, message}} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, duration} <- validate_duration(params) do

      agent_name = agent[:name] || "Unknown Agent"
      duration_text = if duration, do: "for #{duration} seconds", else: "indefinitely"
      Logger.info("Agent #{agent_name} muting channel #{channel_id} in guild #{guild_id} #{duration_text}")

      mute_end_time = if duration do
        DateTime.add(DateTime.utc_now(), duration, :second) |> DateTime.to_iso8601()
      else
        nil
      end

      case Client.request(:patch, "/users/@me/guilds/#{guild_id}/channels/#{channel_id}", %{json: %{
        muted: true,
        mute_end_time: mute_end_time
      }}) do
        {:ok, _} ->
          Logger.info("Successfully muted channel #{channel_id} in guild #{guild_id} #{duration_text}")
          {:ok, %{muted: true, channel_id: channel_id, guild_id: guild_id, duration: duration}}
        error ->
          Logger.error("Failed to mute channel #{channel_id} in guild #{guild_id}: #{inspect(error)}")
          error
      end
    end
  end

  defp validate_param(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, "Missing or invalid #{key}"}
    end
  end

  defp validate_duration(params) do
    case Map.get(params, :duration) do
      nil -> {:ok, nil}
      duration when is_integer(duration) and duration >= 0 -> {:ok, duration}
      _ -> {:error, "Duration must be a non-negative integer or nil"}
    end
  end
end
