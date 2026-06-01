defmodule Lux.Lenses.YouTube.Channels.GetChannel do
  @moduledoc """
  Reads YouTube channel metadata and normalizes hidden/missing statistics.
  """

  alias Lux.Integrations.YouTube.Client

  def view do
    Lux.Lens.new(
      name: "Get YouTube Channel",
      module_name: inspect(__MODULE__),
      description:
        "Gets YouTube channel snippet and statistics by channel id or authenticated owner",
      schema: %{
        type: :object,
        properties: %{
          id: %{type: :string, description: "YouTube channel id"},
          mine: %{type: :boolean, description: "Fetch the authenticated user's channel"},
          access_token: %{type: :string, description: "OAuth access token"}
        },
        required: ["access_token"]
      }
    )
  end

  def focus(input, _opts \\ %{}) do
    params =
      %{"part" => "snippet,statistics"}
      |> maybe_put("id", Client.get(input, :id))
      |> maybe_put("mine", Client.get(input, :mine))

    input
    |> Map.new()
    |> Map.put("params", params)
    |> then(&Client.request(:get, "/channels", &1))
    |> case do
      {:ok, %{"items" => [channel | _]}} -> {:ok, normalize_channel(channel)}
      {:ok, %{"items" => []}} -> {:error, :channel_not_found}
      other -> other
    end
  end

  defp normalize_channel(channel) do
    statistics = channel["statistics"] || %{}

    %{
      id: channel["id"],
      title: get_in(channel, ["snippet", "title"]),
      description: get_in(channel, ["snippet", "description"]),
      custom_url: get_in(channel, ["snippet", "customUrl"]),
      statistics: %{
        view_count: parse_integer(statistics["viewCount"]),
        subscriber_count: parse_integer(statistics["subscriberCount"]),
        hidden_subscriber_count: statistics["hiddenSubscriberCount"] == true,
        video_count: parse_integer(statistics["videoCount"])
      },
      raw: channel
    }
  end

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> number
      _ -> nil
    end
  end

  defp parse_integer(_), do: nil

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
