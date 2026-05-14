defmodule Lux.Prisms.Coinbase.AdvancedTradeOpsPrism do
  @moduledoc """
  Prism wrapper for Coinbase Advanced Trade operation planning.
  """

  use Lux.Prism,
    name: "Coinbase Advanced Trade Ops",
    description:
      "Builds Coinbase REST, WebSocket, order, market data, account, portfolio, and rate-limit plans",
    input_schema: %{
      type: :object,
      properties: %{
        product_id: %{type: :string, description: "Coinbase product ID, for example BTC-USD"},
        side: %{type: :string, description: "BUY or SELL"},
        order_type: %{type: :string, description: "market, limit, or stop_limit"},
        base_size: %{type: :string, description: "Base asset size for orders"},
        quote_size: %{type: :string, description: "Quote asset size for market orders"},
        limit_price: %{type: :string, description: "Limit price for limit orders"},
        channels: %{type: :array, description: "WebSocket channels to subscribe to"},
        accounts: %{type: :array, description: "Coinbase account payloads"},
        prices: %{type: :object, description: "Currency to USD price map"}
      },
      required: ["product_id"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        rest_api: %{type: :array},
        websocket: %{type: :object},
        order_management: %{type: :object},
        market_data: %{type: :object},
        portfolio: %{type: :object},
        rate_limits: %{type: :object},
        safety: %{type: :object}
      },
      required: ["rest_api", "websocket", "order_management", "market_data", "portfolio"]
    }

  alias Lux.Integrations.Coinbase.AdvancedTrade

  @impl true
  def handler(input, _context) when is_map(input) do
    {:ok, AdvancedTrade.plan(input)}
  end
end
