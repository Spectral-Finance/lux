defmodule Lux.Prisms.Discord.Channels.SetChannelNotificationSettings do
  @moduledoc """
  A prism for updating notification settings for a Discord channel.
  Supports various notification settings including notification level, message notifications,
  mention suppressions, mobile push notifications, and muting.

  ## Examples
      # Update all notification settings
      iex> SetChannelNotificationSettings.handler(%{
      ...>   channel_id: "123456789",
      ...>   guild_id: "987654321",
      ...>   notification_level: 1,
      ...>   message_notifications: 2,
      ...>   suppress_everyone: true,
      ...>   suppress_roles: true,
      ...>   mobile_push: false,
      ...>   mute_until: "2024-12-31T23:59:59Z"
      ...> }, %{name: "Agent"})
      {:ok, %{updated: true, channel_id: "123456789", guild_id: "987654321", settings: %{...}}}

      # Update partial settings
      iex> SetChannelNotificationSettings.handler(%{
      ...>   channel_id: "123456789",
      ...>   guild_id: "987654321",
      ...>   notification_level: 2,
      ...>   suppress_everyone: true
      ...> }, %{name: "Agent"})
      {:ok, %{updated: true, channel_id: "123456789", guild_id: "987654321", settings: %{...}}}
  """

  use Lux.Prism,
    name: "Set Discord Channel Notification Settings",
    description: "Updates notification settings for a Discord channel",
    input_schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to update notification settings",
          pattern: "^[0-9]{17,20}$"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild containing the channel",
          pattern: "^[0-9]{17,20}$"
        },
        notification_level: %{
          type: :integer,
          description: "The notification level (0: All Messages, 1: Only @mentions, 2: No notifications)",
          enum: [0, 1, 2]
        },
        message_notifications: %{
          type: :integer,
          description: "Message notification settings (0: Server default, 1: All, 2: Only @mentions, 3: None)",
          enum: [0, 1, 2, 3]
        },
        suppress_everyone: %{
          type: :boolean,
          description: "Whether to suppress @everyone and @here mentions"
        },
        suppress_roles: %{
          type: :boolean,
          description: "Whether to suppress role mentions"
        },
        mobile_push: %{
          type: :boolean,
          description: "Whether to enable mobile push notifications"
        },
        mute_until: %{
          type: [:string, :null],
          description: "ISO8601 timestamp until when the channel should be muted, or null to unmute"
        }
      },
      required: ["channel_id", "guild_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        updated: %{
          type: :boolean,
          description: "Whether the notification settings were successfully updated"
        },
        channel_id: %{
          type: :string,
          description: "The ID of the channel that was updated"
        },
        guild_id: %{
          type: :string,
          description: "The ID of the guild containing the channel"
        },
        settings: %{
          type: :object,
          description: "The current notification settings",
          properties: %{
            notification_level: %{
              type: :integer,
              description: "The current notification level"
            },
            message_notifications: %{
              type: :integer,
              description: "The current message notification settings"
            },
            suppress_everyone: %{
              type: :boolean,
              description: "Whether @everyone and @here mentions are suppressed"
            },
            suppress_roles: %{
              type: :boolean,
              description: "Whether role mentions are suppressed"
            },
            mobile_push: %{
              type: :boolean,
              description: "Whether mobile push notifications are enabled"
            },
            mute_until: %{
              type: [:string, :null],
              description: "When the channel mute will expire, or null if not muted"
            }
          }
        }
      },
      required: ["updated"]
    }

  alias Lux.Integrations.Discord.Client
  require Logger

  @doc """
  Handles the request to update notification settings for a Discord channel.

  Returns {:ok, %{updated: true, channel_id: channel_id, guild_id: guild_id, settings: settings}} on success.
  Returns {:error, reason} on failure.
  """
  def handler(params, agent) do
    with {:ok, channel_id} <- validate_param(params, :channel_id),
         {:ok, guild_id} <- validate_param(params, :guild_id),
         {:ok, settings} <- build_settings(params) do

      agent_name = agent[:name] || "Unknown Agent"
      Logger.info("Agent #{agent_name} updating notification settings for channel #{channel_id} in guild #{guild_id}")

      case Client.request(:patch, "/users/@me/guilds/#{guild_id}/channels/#{channel_id}", %{json: settings}) do
        {:ok, response} ->
          settings = normalize_settings(response)
          Logger.info("Successfully updated notification settings for channel #{channel_id} in guild #{guild_id}")
          {:ok, %{
            updated: true,
            channel_id: channel_id,
            guild_id: guild_id,
            settings: settings
          }}
        error ->
          Logger.error("Failed to update notification settings for channel #{channel_id} in guild #{guild_id}: #{inspect(error)}")
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

  defp build_settings(params) do
    settings = %{}
    |> maybe_add_setting(params, "notification_level")
    |> maybe_add_setting(params, "message_notifications")
    |> maybe_add_setting(params, "suppress_everyone")
    |> maybe_add_setting(params, "suppress_roles")
    |> maybe_add_setting(params, "mobile_push")
    |> maybe_add_setting(params, "mute_until")

    {:ok, settings}
  end

  defp maybe_add_setting(settings, params, key) do
    case Map.get(params, String.to_atom(key)) do
      nil -> settings
      value -> Map.put(settings, key, value)
    end
  end

  defp normalize_settings(response) do
    %{
      notification_level: response["notification_level"] || 0,
      message_notifications: response["message_notifications"] || 0,
      suppress_everyone: response["suppress_everyone"] || false,
      suppress_roles: response["suppress_roles"] || false,
      mobile_push: Map.get(response, "mobile_push", true),
      mute_until: response["mute_until"]
    }
  end
end
