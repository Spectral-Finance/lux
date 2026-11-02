defmodule Lux.YouTube.GrowthEngine.CompetitorAnalyzer do
  @moduledoc """
  Analyzes competitor channel velocity, topical market share, upload cadences,
  and extracts high-opportunity breakout topics.
  """

  @type competitor_profile :: %{
          channel_name: String.t(),
          estimated_subscribers: non_neg_integer(),
          monthly_views: non_neg_integer(),
          upload_frequency_per_week: float(),
          average_views_per_video: non_neg_integer(),
          breakout_topics: list(String.t())
        }

  @type competitive_landscape :: %{
          niche: String.t(),
          market_share_percentage: float(),
          top_competitors: list(competitor_profile()),
          breakout_opportunities: list(map()),
          threat_level: :low | :moderate | :high
        }

  @doc """
  Evaluates channel positioning against a list of competitors in the same niche.
  """
  @spec benchmark_competitors(non_neg_integer(), list(map()), String.t()) :: competitive_landscape()
  def benchmark_competitors(my_monthly_views, competitors, niche \\ "tech") when is_list(competitors) do
    comp_views_sum =
      Enum.reduce(competitors, 0, fn c, acc ->
        acc + get_val(c, :monthly_views, 0)
      end)

    total_market_views = my_monthly_views + comp_views_sum

    market_share =
      if total_market_views > 0 do
        Float.round((my_monthly_views / total_market_views) * 100, 2)
      else
        0.0
      end

    profiles =
      Enum.map(competitors, fn c ->
        views = get_val(c, :monthly_views, 10_000)
        videos_per_month = max(get_val(c, :monthly_uploads, 4), 1)
        freq = Float.round(videos_per_month / 4.0, 1)
        avg_views = div(views, videos_per_month)
        topics = get_val(c, :breakout_topics, ["AI Architecture", "Elixir OTP", "Scaling"])

        %{
          channel_name: get_val(c, :channel_name, "Competitor"),
          estimated_subscribers: get_val(c, :subscribers, 25_000),
          monthly_views: views,
          upload_frequency_per_week: freq,
          average_views_per_video: avg_views,
          breakout_topics: topics
        }
      end)

    breakout_opps =
      profiles
      |> Enum.flat_map(& &1.breakout_topics)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_t, count} -> count end, :desc)
      |> Enum.take(3)
      |> Enum.map(fn {topic, frequency} ->
        %{
          topic: topic,
          competitor_coverage_count: frequency,
          opportunity_score: 85.0 + frequency * 3.0,
          recommendation: "Produce an authoritative, counter-narrative deep dive on '#{topic}'"
        }
      end)

    threat =
      cond do
        market_share < 10.0 -> :high
        market_share < 30.0 -> :moderate
        true -> :low
      end

    %{
      niche: niche,
      market_share_percentage: market_share,
      top_competitors: profiles,
      breakout_opportunities: breakout_opps,
      threat_level: threat
    }
  end

  defp get_val(map, key, default) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end
end
