defmodule Lux.Prisms.Discord.Events.NotifyEventParticipants do
  @moduledoc """
  A prism for notifying participants of a Discord scheduled event.

  Sends a message to the event's channel or DMs interested users.
  """

  use Lux.Prism,
    name: "Notify Discord Event Participants",
    description: "Sends notification to Discord event participants",
    input_schema: %{
      type: :object,
      properties: %{
        guild_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        event_id: %{type: :string, pattern: "^[0-9]{17,20}$"},
        channel_id: %{type: :string, pattern: "^[0-9]{17,20}$", description: "Channel to post notification"},
        message: %{type: :string, maxLength: 2000, description: "Notification message"},
        dm_interested: %{type: :boolean, default: false, description: "DM users who marked interested"}
      },
      required: ["guild_id", "event_id", "channel_id", "message"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        notified: %{type: :boolean},
        guild_id: %{type: :string},
        event_id: %{type: :string},
        channel_message_id: %{type: :string},
        dm_count: %{type: :integer}
      },
      required: ["notified", "guild_id", "event_id", "channel_message_id", "dm_count"]
    }

  alias Lux.Integrations.Discord.Client
  alias Lux.Prisms.Discord.Helpers
  require Logger

  @doc """
  Notifies participants of a Discord scheduled event.

  Returns {:ok, %{notified: true, guild_id: ..., event_id: ..., channel_message_id: ..., dm_count: ...}}.
  """
  def handler(params, agent) do
    with {:ok, guild_id} <- Helpers.validate_string(params, :guild_id),
         {:ok, event_id} <- Helpers.validate_string(params, :event_id),
         {:ok, channel_id} <- Helpers.validate_string(params, :channel_id),
         {:ok, message} <- Helpers.validate_string(params, :message),
         {:ok, dm_interested} <- Helpers.optional(params, :dm_interested, false) do

      agent_name = get_in(agent, [:agent, :name]) || agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} notifying participants for event #{event_id}")

      opts = Helpers.client_opts(params)

      # Post to channel
      channel_result = Client.request_with_retry(:post, "/channels/#{channel_id}/messages", 
        Map.put(opts, :json, %{content: message}))

      channel_message_id = case channel_result do
        {:ok, %{"id" => id}} -> id
        _ -> "failed"
      end

      dm_count = 0

      # DM interested users if requested
      if dm_interested do
        case fetch_interested_users(guild_id, event_id) do
          {:ok, users} ->
            dm_count = Enum.count(users)
            Enum.each(users, fn user ->
              send_dm(user, message)
            end)
          
          error ->
            Logger.error("Failed to fetch interested users for event #{event_id}: #{inspect(error)}")
        end
      end

      {:ok, %{
        notified: true,
        guild_id: guild_id,
        event_id: event_id,
        channel_message_id: channel_message_id,
        dm_count: dm_count
      }}
    end
  end

  defp fetch_interested_users(guild_id, event_id) do
    opts = client_opts(%{})
    case Client.request_with_retry(:get, "/guilds/#{guild_id}/scheduled-events/#{event_id}/users", opts) do
      {:ok, users} -> {:ok, users}
      error -> error
    end
  end

  defp send_dm(user_id, message) do
    opts = client_opts(%{})
    
    # Create DM channel
    case Client.request_with_retry(:post, "/users/#{user_id}/channels", 
      Map.put(opts, :json, %{recipient_id: user_id})) do
      {:ok, %{"id" => dm_channel_id}} ->
        Client.request_with_retry(:post, "/channels/#{dm_channel_id}/messages",
          Map.put(opts, :json, %{content: message}))
      _ -> :error
    end
  end

  defp client_opts(opts) do
    Lux.Prisms.Discord.Helpers.client_opts(opts)
  end
end