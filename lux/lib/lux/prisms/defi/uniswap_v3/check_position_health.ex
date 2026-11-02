defmodule Lux.Prisms.Defi.UniswapV3.CheckPositionHealthPrism do
  @moduledoc """
  Evaluates in-range active status, impermanent loss impact, and operational health score for a position.
  """

  use Lux.Prism,
    name: "Check Uniswap V3 Position Health",
    description: "Monitors position active status, health score, and impermanent loss alerts",
    input_schema: %{
      type: :object,
      properties: %{
        position: %{type: :object, description: "Position map with tick bounds and token_id"},
        current_tick: %{type: :integer, description: "Current pool tick"},
        entry_price: %{type: :number, description: "Price when position was minted"},
        current_price: %{type: :number, description: "Current pool price"},
        price_lower: %{type: :number, description: "Lower boundary price"},
        price_upper: %{type: :number, description: "Upper boundary price"}
      },
      required: ["position", "current_tick", "entry_price", "current_price", "price_lower", "price_upper"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        token_id: %{type: :string},
        in_range: %{type: :boolean},
        health_score: %{type: :integer},
        status: %{type: :string},
        il_pct: %{type: :number},
        alerts: %{type: :array, items: %{type: :string}}
      },
      required: ["token_id", "in_range", "health_score", "status"]
    }

  alias Lux.Defi.UniswapV3.Monitor

  def handler(input, _ctx) do
    raw_pos = Map.get(input, :position) || Map.get(input, "position")
    current_tick = Map.get(input, :current_tick) || Map.get(input, "current_tick")
    p_entry = Map.get(input, :entry_price) || Map.get(input, "entry_price")
    p_current = Map.get(input, :current_price) || Map.get(input, "current_price")
    p_lower = Map.get(input, :price_lower) || Map.get(input, "price_lower")
    p_upper = Map.get(input, :price_upper) || Map.get(input, "price_upper")

    position = %{
      token_id: Map.get(raw_pos, :token_id) || Map.get(raw_pos, "token_id", "pos_default"),
      tick_lower: Map.get(raw_pos, :tick_lower) || Map.get(raw_pos, "tick_lower", 0),
      tick_upper: Map.get(raw_pos, :tick_upper) || Map.get(raw_pos, "tick_upper", 1000)
    }

    report = Monitor.check_health(position, current_tick, p_entry, p_current, p_lower, p_upper)

    {:ok,
     %{
       token_id: to_string(report.token_id),
       in_range: report.in_range?,
       health_score: report.health_score,
       status: to_string(report.status),
       il_pct: report.il_pct,
       alerts: report.alerts
     }}
  end
end
