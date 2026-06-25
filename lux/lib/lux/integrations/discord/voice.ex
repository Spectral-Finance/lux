defmodule Lux.Integrations.Discord.Voice do
  @moduledoc """
  Discord Voice API and Gateway protocol helpers.

  Provides REST API calls for voice state management and voice region listing,
  plus a voice gateway protocol module for building Gateway voice payloads.

  ## REST API Operations

    * `list_regions/1` - List available voice regions
    * `update_voice_state/3` - Modify the current user's voice state
    * `get_guild_voice_states/2` - (Future) Requires privileged intents

  ## Gateway Protocol

    * `voice_state_update_payload/2` - Build opcode 4 payload
    * `voice_server_ping_payload/0` - Build opcode 8 payload
    * `identify_payload/1` - Build voice identify payload

  Discord Voice Gateway opcodes and payload formats are defined per the
  [Discord Voice Gateway documentation](https://discord.com/developers/docs/topics/voice-connections).
  """

  alias Lux.Integrations.Discord.Client

  @voice_regions_endpoint "/voice/regions"
  @voice_state_endpoint "/guilds"

  @gateway_opcodes %{
    identify: 0,
    select_protocol: 1,
    ready: 2,
    heartbeat: 3,
    session_description: 4,
    speaking: 5,
    heartbeat_ack: 6,
    resume: 7,
    hello: 8,
    resumed: 9,
    client_disconnect: 13
  }

  @status_types %{
    idle: "idle",
    dnd: "dnd",
    online: "online",
    invisible: "invisible",
    offline: "offline"
  }

  @type request_opts :: keyword() | map()

  @doc """
  Lists available Discord voice regions.

  Returns a list of voice region objects from the Discord API.

  ## Options

    * `:token` - Discord API token
    * `:plug` - Test plug for mocking

  ## Examples

      {:ok, regions} = Voice.list_regions()
      [%{"id" => "us-west", "name" => "US West", ...}, ...]

  """
  @spec list_regions(request_opts()) :: {:ok, [map()]} | {:error, term()}
  def list_regions(opts \\ %{}) do
    case Client.request(:get, @voice_regions_endpoint, opts) do
      {:ok, regions} when is_list(regions) -> {:ok, regions}
      {:ok, other} -> {:error, {:unexpected_response, other}}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Updates the current user's voice state in a guild.

  Joins, moves to, or disconnects from a voice channel. Requires the
  bot to have `CONNECT` permission for the target channel.

  ## Parameters

    * `guild_id` - The guild ID
    * `channel_id` - The channel ID to join/move to, or `nil` to disconnect
    * `opts` - Options including `:self_mute` and `:self_deaf`

  ## Examples

      # Join a voice channel
      {:ok, _} = Voice.update_voice_state("guild_id", "channel_id")

      # Disconnect from voice
      {:ok, _} = Voice.update_voice_state("guild_id", nil)

      # Join muted and deafened
      {:ok, _} = Voice.update_voice_state("guild_id", "channel_id", self_mute: true, self_deaf: true)

  """
  @spec update_voice_state(String.t(), String.t() | nil, request_opts()) ::
          {:ok, map()} | {:error, term()}
  def update_voice_state(guild_id, channel_id, opts \\ %{}) do
    body =
      %{channel_id: channel_id}
      |> maybe_put(:self_mute, get_opt(opts, :self_mute))
      |> maybe_put(:self_deaf, get_opt(opts, :self_deaf))

    case Client.request(:patch, "#{@voice_state_endpoint}/#{guild_id}/voice-states/@me", Map.put(opts, :json, body)) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Builds a Voice State Update payload (Gateway opcode 4).

  This payload tells the Gateway which voice channel the bot wants to join.

  ## Parameters

    * `guild_id` - The guild ID
    * `channel_id` - The channel ID to join, or `nil` to disconnect
    * `opts` - Options including `:self_mute` and `:self_deaf`

  ## Examples

      payload = Voice.voice_state_update_payload("guild_id", "channel_id")
      # => %{op: 4, d: %{guild_id: "guild_id", channel_id: "channel_id", self_mute: false, self_deaf: false}}

  """
  @spec voice_state_update_payload(String.t(), String.t() | nil, keyword()) :: map()
  def voice_state_update_payload(guild_id, channel_id, opts \\ []) do
    %{
      op: 4,
      d: %{
        guild_id: guild_id,
        channel_id: channel_id,
        self_mute: Keyword.get(opts, :self_mute, false),
        self_deaf: Keyword.get(opts, :self_deaf, false)
      }
    }
  end

  @doc """
  Builds a Voice Server Ping payload (Gateway opcode 8).

  Used to request a voice server endpoint for connecting to a voice channel.
  """
  @spec voice_server_ping_payload() :: map()
  def voice_server_ping_payload do
    %{op: 8, d: %{token: "", guild_id: nil, endpoint: nil}}
  end

  @doc """
  Builds a Voice Identify payload for connecting to a voice gateway.

  Sent after receiving a Voice Ready (opcode 2) event to authenticate
  with the voice gateway.

  ## Parameters

    * `server_id` - The guild ID
    * `user_id` - The bot user ID
    * `session_id` - The voice session ID from the Voice State Update event
    * `token` - The voice token from the Voice Server Update event

  """
  @spec identify_payload(String.t(), String.t(), String.t(), String.t()) :: map()
  def identify_payload(server_id, user_id, session_id, token) do
    %{
      op: @gateway_opcodes.identify,
      d: %{
        server_id: server_id,
        user_id: user_id,
        session_id: session_id,
        token: token
      }
    }
  end

  @doc """
  Builds a Resume payload for reconnecting to a voice gateway.

  Used when the voice connection drops and needs to be resumed.
  """
  @spec resume_payload(String.t(), String.t(), String.t(), String.t()) :: map()
  def resume_payload(server_id, session_id, token, seq) do
    %{
      op: @gateway_opcodes.resume,
      d: %{
        server_id: server_id,
        session_id: session_id,
        token: token,
        seq: seq
      }
    }
  end

  @doc """
  Builds a Speaking payload (opcode 5) to indicate the bot is speaking.

  ## Parameters

    * `speaking` - Bitfield: 0 = none, 1 = microphone, 2 = soundshare, 4 = priority
    * `delay` - Audio delay in ms (typically 0)
    * `ssrc` - The SSRC from the Ready event

  """
  @spec speaking_payload(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: map()
  def speaking_payload(speaking \\ 1, delay \\ 0, ssrc \\ 0) do
    %{
      op: @gateway_opcodes.speaking,
      d: %{
        speaking: speaking,
        delay: delay,
        ssrc: ssrc
      }
    }
  end

  @doc """
  Returns the map of Gateway voice opcodes.
  """
  @spec gateway_opcodes() :: map()
  def gateway_opcodes, do: @gateway_opcodes

  @doc """
  Returns the map of valid status types.
  """
  @spec status_types() :: map()
  def status_types, do: @status_types

  @doc """
  Validates a status string against known Discord statuses.

  ## Examples

      iex> Voice.validate_status("online")
      {:ok, "online"}

      iex> Voice.validate_status("invalid")
      {:error, :invalid_status}

  """
  @spec validate_status(String.t()) :: {:ok, String.t()} | {:error, term()}
  def validate_status(status) when is_binary(status) do
    if status in Map.values(@status_types) do
      {:ok, status}
    else
      {:error, :invalid_status}
    end
  end

  def validate_status(status) when is_atom(status) do
    case Map.get(@status_types, status) do
      nil -> {:error, :invalid_status}
      val -> {:ok, val}
    end
  end

  def validate_status(_), do: {:error, :invalid_status}

  # Private helpers

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp get_opt(opts, key) when is_map(opts), do: Map.get(opts, key)
  defp get_opt(opts, key) when is_list(opts), do: Keyword.get(opts, key)
end
