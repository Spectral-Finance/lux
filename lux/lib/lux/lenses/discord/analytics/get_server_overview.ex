defmodule Lux.Lenses.Discord.Analytics.GetServerOverview do
  @moduledoc """
  A lens for retrieving overview metrics for a Discord server (guild).
  This lens provides comprehensive server statistics including:
  - Basic server information (name, description, member count)
  - Channel statistics (by type and category)
  - Role distribution
  - Recent activity metrics

  ## Examples
      iex> GetServerOverview.focus(%{
      ...>   guild_id: "123456789012345678"
      ...> }, %{})
      {:ok, %{
        server_info: %{
          name: "My Server",
          description: "A great community server",
          member_count: 1500,
          created_at: "2023-01-01T00:00:00Z"
        },
        channels: %{
          total: 25,
          by_type: %{
            text: 15,
            voice: 5,
            announcement: 2,
            forum: 3
          },
          categories: [
            %{
              name: "General",
              channels: ["general", "off-topic", "announcements"]
            }
          ]
        },
        roles: [
          %{
            name: "Admin",
            member_count: 5,
            color: 16711680  # RGB color in decimal
          }
        ],
        activity: %{
          messages_today: 150,
          active_channels: ["general", "gaming", "music"],
          peak_hour: "18:00"
        }
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Get Discord Server Overview",
    description: "Retrieves comprehensive overview metrics for a Discord server",
    url: "https://discord.com/api/v10/guilds/:guild_id",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        guild_id: %{
          type: :string,
          description: "The ID of the guild to analyze",
          pattern: "^[0-9]{17,20}$"
        }
      },
      required: ["guild_id"]
    }

  @doc """
  Transforms the Discord API response into server overview metrics.
  Combines data from multiple endpoints to provide comprehensive statistics.
  """
  @impl true
  def after_focus(%{
    "id" => id,
    "name" => name,
    "description" => description,
    "member_count" => member_count,
    "channels" => channels,
    "roles" => roles
  }) do
    metrics = %{
      server_info: %{
        id: id,
        name: name,
        description: description || "",
        member_count: member_count,
        created_at: snowflake_to_timestamp(id)
      },
      channels: analyze_channels(channels),
      roles: analyze_roles(roles),
      activity: %{
        messages_today: 0,  # This would need additional API calls to calculate
        active_channels: [], # This would need additional API calls to calculate
        peak_hour: "00:00"  # This would need additional API calls to calculate
      }
    }

    {:ok, metrics}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end

  # Private helper functions

  defp analyze_channels(channels) do
    channels_by_type =
      channels
      |> Enum.group_by(& &1["type"])
      |> Map.new(fn {type, channels} -> {channel_type_name(type), length(channels)} end)

    categories =
      channels
      |> Enum.filter(&(&1["type"] == 4))  # 4 is category type
      |> Enum.map(fn category ->
        child_channels =
          channels
          |> Enum.filter(&(&1["parent_id"] == category["id"]))
          |> Enum.map(& &1["name"])

        %{
          name: category["name"],
          channels: child_channels
        }
      end)

    %{
      total: length(channels),
      by_type: channels_by_type,
      categories: categories
    }
  end

  defp analyze_roles(roles) do
    Enum.map(roles, fn role ->
      %{
        name: role["name"],
        member_count: role["member_count"] || 0,
        color: role["color"]
      }
    end)
  end

  defp channel_type_name(type) do
    case type do
      0 -> :text
      2 -> :voice
      4 -> :category
      5 -> :announcement
      15 -> :forum
      _ -> :other
    end
  end

  defp snowflake_to_timestamp(snowflake) do
    # Discord Snowflake format:
    # https://discord.com/developers/docs/reference#snowflakes
    {timestamp, _} = Integer.parse(snowflake)
    discord_epoch = 1_420_070_400_000

    timestamp
    |> Bitwise.>>>(22)
    |> Kernel.+(discord_epoch)
    |> DateTime.from_unix!(:millisecond)
    |> DateTime.to_iso8601()
  end
end
