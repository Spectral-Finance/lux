defmodule Lux.YouTube.GrowthEngine.RoiTracker do
  @moduledoc """
  Tracks production expenditure vs revenue, calculates return on investment (ROI),
  profit margins, and breakeven timelines for YouTube content production.
  """

  @type production_costs :: %{
          scriptwriting_usd: float(),
          video_editing_usd: float(),
          thumbnail_design_usd: float(),
          voiceover_or_talent_usd: float(),
          tooling_and_hosting_usd: float()
        }

  @type roi_analysis :: %{
          video_or_campaign_id: String.t(),
          total_production_cost_usd: float(),
          total_gross_revenue_usd: float(),
          net_profit_usd: float(),
          roi_multiplier: float(),
          profit_margin_percentage: float(),
          is_profitable: boolean(),
          breakeven_status: :profitable | :at_breakeven | :unprofitable
        }

  @doc """
  Computes complete ROI metrics comparing production costs against gross earned revenue.
  """
  @spec calculate_roi(String.t(), map(), float()) :: roi_analysis()
  def calculate_roi(campaign_id, costs, gross_revenue) when is_map(costs) do
    c_script = get_val(costs, :scriptwriting_usd, 0.0)
    c_edit = get_val(costs, :video_editing_usd, 0.0)
    c_thumb = get_val(costs, :thumbnail_design_usd, 0.0)
    c_talent = get_val(costs, :voiceover_or_talent_usd, 0.0)
    c_tools = get_val(costs, :tooling_and_hosting_usd, 0.0)

    total_cost = Float.round(c_script + c_edit + c_thumb + c_talent + c_tools, 2)
    revenue = Float.round(gross_revenue, 2)
    net_profit = Float.round(revenue - total_cost, 2)

    roi_mult =
      if total_cost > 0 do
        Float.round(revenue / total_cost, 2)
      else
        0.0
      end

    margin =
      if revenue > 0 do
        Float.round((net_profit / revenue) * 100.0, 2)
      else
        -100.0
      end

    status =
      cond do
        net_profit > 0.0 -> :profitable
        net_profit == 0.0 -> :at_breakeven
        true -> :unprofitable
      end

    %{
      video_or_campaign_id: campaign_id,
      total_production_cost_usd: total_cost,
      total_gross_revenue_usd: revenue,
      net_profit_usd: net_profit,
      roi_multiplier: roi_mult,
      profit_margin_percentage: margin,
      is_profitable: net_profit > 0.0,
      breakeven_status: status
    }
  end

  defp get_val(map, key, default) do
    Map.get(map, key, Map.get(map, to_string(key), default))
  end
end
