defmodule Lux.Lenses.Twitter.Analytics.TrendAnalysis do
  @moduledoc """
  Lens for analyzing trends and trending topics via the Twitter/X API v1.1.

  Retrieves trending topics for specified WOEID (Where On Earth ID) locations,
  with volume data and trend categorization.

  ## Examples

      iex> TrendAnalysis.focus(%{woeid: 1})
      {:ok, %{trends: [%{name: "#Elixir", tweet_volume: 15000, ...}], location: "Worldwide"}}

      iex> TrendAnalysis.focus(%{woeid: 23424977})
      {:ok, %{trends: [...], location: "United States"}}
  """

  use Lux.Lens,
    name: "Twitter Trend Analysis",
    description: "Retrieves and analyzes trending topics for specified geographic locations",
    url: "https://api.twitter.com/1.1/trends/place.json",
    method: :get,
    schema: %{
      type: :object,
      properties: %{
        woeid: %{
          type: :integer,
          description: "Yahoo WOEID for the location (1 = Worldwide, 23424977 = US)"
        },
        exclude_hashtags: %{
          type: :boolean,
          description: "Exclude hashtag trends, return only non-hashtag trends (default: false)"
        }
      },
      required: ["woeid"]
    }

  alias Lux.Integrations.Twitter

  def before_focus(params) do
    woeid = Map.get(params, :woeid, 1)

    params
    |> Map.put(:id, woeid)
    |> Map.delete(:woeid)
  end

  def after_focus([%{trends: trends, locations: locations}]) do
    location_name = case locations do
      [%{name: name} | _] -> name
      _ -> "Unknown"
    end

    # Filter and sort trends by volume
    filtered_trends = trends
    |> Enum.filter(fn trend ->
      name = Map.get(trend, "name", "")
      not String.starts_with?(name, "#") == false  # Keep all by default
    end)
    |> Enum.map(fn trend ->
      %{
        name: trend["name"],
        url: Map.get(trend, "url", ""),
        tweet_volume: Map.get(trend, "tweet_volume"),
        promoted_content: Map.get(trend, "promoted_content", false)
      }
    end)
    |> Enum.sort_by(& &1.tweet_volume || 0, :desc)

    {:ok, %{
      location: location_name,
      trends: filtered_trends,
      count: length(filtered_trends)
    }}
  end

  def after_focus(%{"errors" => errors}) do
    Twitter.parse_error(%{"errors" => errors})
  end

  def after_focus(body), do: {:ok, body}
end
