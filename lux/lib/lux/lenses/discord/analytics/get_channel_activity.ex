defmodule Lux.Lenses.Discord.Analytics.GetChannelActivity do
  @moduledoc """
  A lens for retrieving activity metrics for a Discord channel.
  This lens provides detailed analytics about channel activity including:
  - Message count over time
  - Active users count
  - Peak activity periods
  - Message type distribution

  ## Examples
      iex> GetChannelActivity.focus(%{
      ...>   channel_id: "123456789012345678",
      ...>   time_range: "24h"  # 24h, 7d, 30d
      ...> }, %{})
      {:ok, %{
        message_count: 150,
        active_users: 25,
        peak_hour: "18:00",
        message_types: %{
          text: 120,
          image: 20,
          link: 10
        },
        activity_timeline: [
          %{hour: "00:00", count: 5},
          %{hour: "01:00", count: 3},
          # ... more hourly data
        ]
      }}
  """

  alias Lux.Integrations.Discord

  use Lux.Lens,
    name: "Get Discord Channel Activity",
    description: "Retrieves detailed activity metrics for a Discord channel",
    url: "https://discord.com/api/v10/channels/:channel_id/messages",
    method: :get,
    headers: Discord.headers(),
    auth: Discord.auth(),
    schema: %{
      type: :object,
      properties: %{
        channel_id: %{
          type: :string,
          description: "The ID of the channel to analyze",
          pattern: "^[0-9]{17,20}$"
        },
        time_range: %{
          type: :string,
          description: "Time range for analysis (24h, 7d, or 30d)",
          enum: ["24h", "7d", "30d"],
          default: "24h"
        },
        limit: %{
          type: :integer,
          description: "Maximum number of messages to analyze",
          minimum: 1,
          maximum: 100,
          default: 100
        }
      },
      required: ["channel_id"]
    }

  @doc """
  Transforms the Discord API response into activity metrics.
  Analyzes message data to generate activity statistics.
  """
  @impl true
  def after_focus(messages) when is_list(messages) do
    metrics = %{
      message_count: length(messages),
      active_users: count_active_users(messages),
      peak_hour: find_peak_hour(messages),
      message_types: analyze_message_types(messages),
      activity_timeline: generate_timeline(messages)
    }

    {:ok, metrics}
  end

  def after_focus(%{"message" => message}) do
    {:error, %{"message" => message}}
  end

  # Private helper functions

  defp count_active_users(messages) do
    messages
    |> Enum.map(& &1["author"]["id"])
    |> Enum.uniq()
    |> length()
  end

  defp find_peak_hour([]) do
    "00:00"
  end

  defp find_peak_hour(messages) do
    messages
    |> Enum.group_by(fn message ->
      {:ok, timestamp, _} = DateTime.from_iso8601(message["timestamp"])
      "#{String.pad_leading("#{timestamp.hour}", 2, "0")}:00"
    end)
    |> Enum.max_by(fn {_hour, msgs} -> length(msgs) end)
    |> elem(0)
  end

  defp analyze_message_types(messages) do
    messages
    |> Enum.reduce(%{text: 0, image: 0, link: 0}, fn message, acc ->
      cond do
        message["attachments"] != [] -> Map.update!(acc, :image, &(&1 + 1))
        String.contains?(message["content"] || "", "http") -> Map.update!(acc, :link, &(&1 + 1))
        true -> Map.update!(acc, :text, &(&1 + 1))
      end
    end)
  end

  defp generate_timeline(messages) do
    messages
    |> Enum.group_by(fn message ->
      {:ok, timestamp, _} = DateTime.from_iso8601(message["timestamp"])
      "#{String.pad_leading("#{timestamp.hour}", 2, "0")}:00"
    end)
    |> Enum.map(fn {hour, msgs} -> %{hour: hour, count: length(msgs)} end)
    |> Enum.sort_by(& &1.hour)
  end
end
