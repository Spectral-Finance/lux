defmodule Lux.Lenses.Discord.Guilds.GetNotificationSettings do
  @moduledoc """
  A lens for fetching server-wide notification settings from a Discord guild.
  This lens provides a simple interface for fetching notification settings with:
  - Minimal required parameters (guild_id)
  - Direct Discord API error propagation
  - Clean response structure

  ## Examples
      iex> GetNotificationSettings.focus(%{
      ...>   guild_id: "123456789"
      ...> })
      {:ok, %{
        default_message_notifications: 0,
        explicit_content_filter: 1,
        system_channel_flags: 0
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Get Discord Guild Notification Settings",
    description: "Fetches server-wide notification settings from a Discord guild",
    url: "https://discord.com/api/v10/guilds/:guild_id",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to fetch notification settings from",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    }

  @doc """
  Transforms the Discord API response into a simpler format focusing on notification settings.
  ## Examples
      iex> after_focus(%{
      ...>   "default_message_notifications" => 0,
      ...>   "explicit_content_filter" => 1,
      ...>   "system_channel_flags" => 0,
      ...>   "other_field" => "ignored"
      ...> })
      {:ok, %{
        default_message_notifications: 0,
        explicit_content_filter: 1,
        system_channel_flags: 0
      }}
  """
  @impl true
  def after_focus(%{"default_message_notifications" => default_notifications, "explicit_content_filter" => content_filter, "system_channel_flags" => system_flags} = _response) do
    {:ok, %{
      default_message_notifications: default_notifications,
      explicit_content_filter: content_filter,
      system_channel_flags: system_flags
    }}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end
end
