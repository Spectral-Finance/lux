defmodule Lux.Lenses.YouTube.RevenueEstimatorLens do
  @moduledoc """
  Lens for estimating YouTube revenue based on video or channel view data.

  Provides revenue estimates using industry-standard CPM (Cost Per Mille)
  ranges and engagement metrics. Estimates are calculated based on views
  and configurable CPM ranges that vary by niche, audience geography,
  and content type.

  ## Important Notes

  - Revenue estimates are approximations based on industry averages
  - Actual revenue varies significantly based on:
    - Audience geography (US/UK/CA audiences have higher CPMs)
    - Content niche (finance/tech CPMs are higher than entertainment)
    - Video length (videos >8min can have mid-roll ads)
    - Seasonality (Q4 CPMs are typically 20-50% higher)
    - Advertiser demand and market conditions

  ## Examples

      # Estimate revenue for a specific video
      Lux.Lenses.YouTube.RevenueEstimatorLens.focus(%{
        video_id: "dQw4w9WgXcQ",
        cpm_range: {2.0, 5.0}
      })

      # Estimate channel revenue with custom CPM
      Lux.Lenses.YouTube.RevenueEstimatorLens.focus(%{
        channel_id: "UC_x5XG1OV2P6uZZ5FSM9Ttw",
        cpm_range: {3.0, 8.0},
        niche: "technology"
      })

  ## Response Format

      %{
        video_id: "dQw4w9WgXcQ",
        title: "Video Title",
        view_count: 1_000_000,
        revenue_estimate: %{
          low: 2000.0,
          high: 5000.0,
          average: 3500.0,
          currency: "USD"
        },
        cpm_used: %{
          low: 2.0,
          high: 5.0,
          average: 3.5
        },
        monetized_view_percentage: 0.75,
        monetized_views: 750_000,
        additional_metrics: %{
          estimated_watch_time_minutes: 250_000,
          rpm: 3.5,
          niche_multiplier: 1.2
        }
      }
  """

  alias Lux.Integrations.YouTube

  use Lux.Lens,
    name: "YouTube Revenue Estimator",
    description: "Estimates YouTube revenue based on views and configurable CPM ranges",
    url: "#{YouTube.base_url()}/videos",
    method: :get,
    headers: YouTube.headers(),
    auth: %{
      type: :custom,
      auth_function: &YouTube.add_api_key/1
    },
    schema: %{
      type: :object,
      properties: %{
        video_id: %{
          type: :string,
          description: "YouTube video ID to estimate revenue for"
        },
        channel_id: %{
          type: :string,
          description: "YouTube channel ID to estimate revenue for (uses total views)"
        },
        cpm_range: %{
          type: :object,
          description: "CPM range in USD (Cost Per Mille / cost per 1000 views)",
          properties: %{
            low: %{type: :number, description: "Low CPM estimate", default: 1.0, minimum: 0.1},
            high: %{type: :number, description: "High CPM estimate", default: 5.0, minimum: 0.1}
          }
        },
        niche: %{
          type: :string,
          description: "Content niche for CPM adjustment",
          default: "general",
          enum: [
            "general",
            "technology",
            "finance",
            "education",
            "entertainment",
            "gaming",
            "lifestyle",
            "health",
            "business",
            "news",
            "sports",
            "music"
          ]
        },
        monetized_view_percentage: %{
          type: :number,
          description: "Percentage of views that are monetized (0.0-1.0)",
          default: 0.75,
          minimum: 0.0,
          maximum: 1.0
        },
        region: %{
          type: :string,
          description: "Primary audience region for CPM adjustment",
          default: "global",
          enum: ["us", "uk", "ca", "au", "eu", "asia", "global", "india", "brazil"]
        }
      },
      oneOf: [
        %{required: ["video_id"]},
        %{required: ["channel_id"]}
      ]
    }

  require Logger

  # Default CPM ranges by niche (in USD per 1000 views)
  @niche_cpm %{
    "technology" => %{low: 3.0, high: 8.0},
    "finance" => %{low: 5.0, high: 15.0},
    "education" => %{low: 2.0, high: 6.0},
    "entertainment" => %{low: 1.0, high: 4.0},
    "gaming" => %{low: 1.5, high: 5.0},
    "lifestyle" => %{low: 1.5, high: 5.0},
    "health" => %{low: 2.5, high: 7.0},
    "business" => %{low: 3.0, high: 10.0},
    "news" => %{low: 2.0, high: 6.0},
    "sports" => %{low: 1.5, high: 5.0},
    "music" => %{low: 0.5, high: 3.0},
    "general" => %{low: 1.0, high: 5.0}
  }

  # Regional CPM multipliers
  @region_multiplier %{
    "us" => 1.5,
    "uk" => 1.3,
    "ca" => 1.3,
    "au" => 1.2,
    "eu" => 1.1,
    "asia" => 0.6,
    "global" => 1.0,
    "india" => 0.3,
    "brazil" => 0.4
  }

  @doc """
  Prepares parameters before making the API request.

  Sets up the appropriate endpoint based on whether video_id or channel_id is provided.
  """
  @impl true
  def before_focus(params) do
    params =
      params
      |> Map.put_new(:part, "snippet,statistics")
      |> case do
        %{video_id: video_id} = params ->
          params
          |> Map.put(:ids, String.trim(video_id))
          |> Map.delete(:video_id)

        %{channel_id: channel_id} = params ->
          # For channel estimation, we need to fetch channel stats first
          # Change the URL to channels endpoint
          url = "#{YouTube.base_url()}/channels"
          params
          |> Map.put(:url, url)
          |> Map.put(:ids, String.trim(channel_id))
          |> Map.put(:part, "snippet,statistics")
          |> Map.delete(:channel_id)

        params ->
          params
      end

    Logger.debug("YouTube RevenueEstimatorLens before_focus: #{inspect(params)}")
    params
  end

  @doc """
  Transforms the YouTube API response into revenue estimates.

  Calculates revenue ranges based on view counts and CPM parameters.

  ## Examples

      iex> after_focus(%{"items" => [%{
      ...>   "id" => "abc123",
      ...>   "snippet" => %{"title" => "Test Video"},
      ...>   "statistics" => %{"viewCount" => "1000000"}
      ...> }}, %{cpm_range: %{low: 2.0, high: 5.0}})
      {:ok, %{video_id: "abc123", revenue_estimate: %{low: 2000.0, high: 5000.0, ...}}}

      iex> after_focus(%{"error" => %{"message" => "Video not found"}})
      {:error, "Video not found"}
  """
  @impl true
  def after_focus(%{"items" => [item | _rest]} = _response) do
    params = Map.get(__MODULE__, :_last_params, %{})
    result = estimate_revenue(item, params)
    Logger.info("Revenue estimate calculated for #{result.title}: #{inspect(result.revenue_estimate)}")
    {:ok, result}
  end

  @impl true
  def after_focus(%{"items" => []}) do
    Logger.warning("YouTube RevenueEstimatorLens: No video/channel found")
    {:error, "No video or channel found. Verify the ID is correct."}
  end

  @impl true
  def after_focus(%{"error" => %{"message" => message}}) do
    Logger.error("YouTube RevenueEstimatorLens API error: #{message}")
    {:error, message}
  end

  @impl true
  def after_focus(%{"error" => error}) when is_binary(error) do
    Logger.error("YouTube RevenueEstimatorLens API error: #{error}")
    {:error, error}
  end

  @impl true
  def after_focus(response) do
    Logger.error("YouTube RevenueEstimatorLens unexpected response: #{inspect(response)}")
    {:error, "Unexpected response format: #{inspect(response)}"}
  end

  # Estimates revenue for a video item
  defp estimate_revenue(item, params) do
    statistics = Map.get(item, "statistics", %{})
    snippet = Map.get(item, "snippet", %{})

    view_count = parse_integer(statistics["viewCount"])
    title = snippet["title"] || "Unknown"

    # Get CPM parameters
    cpm_range = params[:cpm_range] || %{low: 1.0, high: 5.0}
    niche = params[:niche] || "general"
    region = params[:region] || "global"
    monetized_pct = params[:monetized_view_percentage] || 0.75

    # Get niche-adjusted CPM
    niche_cpm = @niche_cpm[niche] || @niche_cpm["general"]
    region_mult = @region_multiplier[region] || 1.0

    # Calculate effective CPM
    effective_low = cpm_range[:low] * region_mult
    effective_high = cpm_range[:high] * region_mult

    # Apply niche multiplier if provided CPM is generic
    niche_mult = niche_cpm[:high] / niche_cpm[:low]
    adjusted_low = effective_low * (1 + (niche_mult - 1) * 0.3)
    adjusted_high = effective_high * (1 + (niche_mult - 1) * 0.3)

    # Calculate monetized views
    monetized_views = round(view_count * monetized_pct)

    # Calculate revenue estimates
    revenue_low = monetized_views / 1000 * adjusted_low
    revenue_high = monetized_views / 1000 * adjusted_high
    revenue_avg = (revenue_low + revenue_high) / 2

    %{
      video_id: item["id"],
      title: title,
      view_count: view_count,
      monetized_views: monetized_views,
      monetized_view_percentage: monetized_pct,
      revenue_estimate: %{
        low: round(revenue_low * 100) / 100,
        high: round(revenue_high * 100) / 100,
        average: round(revenue_avg * 100) / 100,
        currency: "USD"
      },
      cpm_used: %{
        low: round(adjusted_low * 100) / 100,
        high: round(adjusted_high * 100) / 100,
        average: round((adjusted_low + adjusted_high) / 2 * 100) / 100,
        niche: niche,
        region: region
      },
      additional_metrics: %{
        rpm: round(revenue_avg / view_count * 1000 * 100) / 100,
        niche_multiplier: round(niche_mult * 100) / 100,
        region_multiplier: region_mult
      }
    }
  end

  defp parse_integer(nil), do: 0
  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _rest} -> int
      :error -> 0
    end
  end
end
