defmodule Lux.Lenses.Discord.Channels.GetChannelNotificationSettings do
  @moduledoc """
  A lens for retrieving notification settings for a specific Discord channel.

  This lens provides a simple interface for fetching channel notification settings with:
  - Minimal required parameters (channel_id)
  - Direct Discord API error propagation
  - Clean response structure

  ## Example
      iex> GetChannelNotificationSettings.focus(%{channel_id: "123456789"})
      {:ok, %{
        muted: false,
        message_notifications: 1,
        mute_config: %{
          end_time: nil,
          selected_time_window: nil
        },
        channel_overrides: %{
          muted: false,
          message_notifications: 0
        }
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Get Channel Notification Settings",
    description: "Retrieve notification settings for a specific channel",
    url: "https://discord.com/api/v10/channels/:channel_id/notification-settings",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to get notification settings from",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["channel_id"]
    }

  @doc """
  Transforms the Discord API response into a simplified notification settings format.

  ## Parameters
    - response: Raw response from Discord API

  ## Returns
    - `{:ok, settings}` - Channel notification settings
    - `{:error, reason}` - Error response from Discord API

  ## Examples
      iex> after_focus(%{
        "muted" => false,
        "message_notifications" => 1,
        "mute_config" => %{
          "end_time" => nil,
          "selected_time_window" => nil
        },
        "channel_overrides" => %{
          "muted" => false,
          "message_notifications" => 0
        }
      })
      {:ok, %{
        muted: false,
        message_notifications: 1,
        mute_config: %{
          end_time: nil,
          selected_time_window: nil
        },
        channel_overrides: %{
          muted: false,
          message_notifications: 0
        }
      }}
  """
  @impl true
  def after_focus(%{
    "muted" => muted,
    "message_notifications" => message_notifications,
    "mute_config" => mute_config,
    "channel_overrides" => channel_overrides
  }) do
    {:ok, %{
      muted: muted,
      message_notifications: message_notifications,
      mute_config: %{
        end_time: mute_config["end_time"],
        selected_time_window: mute_config["selected_time_window"]
      },
      channel_overrides: %{
        muted: channel_overrides["muted"],
        message_notifications: channel_overrides["message_notifications"]
      }
    }}
  end

  def after_focus(%{"message" => _} = error), do: {:error, error}
end
