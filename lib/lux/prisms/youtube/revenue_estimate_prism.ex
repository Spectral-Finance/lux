defmodule Lux.Prisms.YouTube.RevenueEstimatePrism do
  @moduledoc """
  A prism that estimates a YouTube video's / channel's ad revenue range
  (lux issue #78 — "YouTube Prism implementation", monetization intelligence).

  Pure and deterministic: given a view count and an optional RPM band (revenue
  per mille / per 1,000 views, in USD) it returns a low/mid/high revenue
  estimate. The default band reflects typical creator RPMs; callers can override
  it for a specific niche. This is an *estimate* for planning, not a guarantee.
  No network call is made here.

  ## Examples
      iex> RevenueEstimatePrism.handler(%{views: 100_000}, %{})
      {:ok, %{views: 100000, rpm_low: 1.0, rpm_high: 5.0,
             revenue_low: 100.0, revenue_high: 500.0, revenue_mid: 300.0}}
  """

  use Lux.Prism,
    name: "YouTube Revenue Estimate",
    description:
      "Estimates a YouTube video's ad revenue range from views and an RPM band",
    input_schema: %{
      type: :object,
      properties: %{
        views: %{type: :integer, description: "Number of monetised views"},
        rpm_low: %{type: :number, description: "Low revenue-per-mille USD (default 1.0)"},
        rpm_high: %{type: :number, description: "High revenue-per-mille USD (default 5.0)"}
      },
      required: ["views"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        views: %{type: :integer},
        rpm_low: %{type: :number},
        rpm_high: %{type: :number},
        revenue_low: %{type: :number},
        revenue_mid: %{type: :number},
        revenue_high: %{type: :number}
      },
      required: ["views", "revenue_low", "revenue_mid", "revenue_high"]
    }

  alias Lux.Prisms.YouTube.Util

  @default_rpm_low 1.0
  @default_rpm_high 5.0

  def handler(params, _agent) do
    views = params |> Map.get(:views, 0) |> Util.to_int()

    rpm_low = params |> Map.get(:rpm_low, @default_rpm_low) |> Util.to_float()
    rpm_high = params |> Map.get(:rpm_high, @default_rpm_high) |> Util.to_float()

    # Guard against a swapped band so low <= high always holds.
    {rpm_low, rpm_high} = if rpm_low <= rpm_high, do: {rpm_low, rpm_high}, else: {rpm_high, rpm_low}

    revenue_low = Util.round_to(views / 1000.0 * rpm_low, 2)
    revenue_high = Util.round_to(views / 1000.0 * rpm_high, 2)
    revenue_mid = Util.round_to((revenue_low + revenue_high) / 2.0, 2)

    result = %{
      views: views,
      rpm_low: rpm_low,
      rpm_high: rpm_high,
      revenue_low: revenue_low,
      revenue_mid: revenue_mid,
      revenue_high: revenue_high
    }

    {:ok, result}
  end
end