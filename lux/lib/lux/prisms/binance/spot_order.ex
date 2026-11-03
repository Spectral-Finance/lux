defmodule Lux.Prisms.Binance.SpotOrderPrism do
  @moduledoc """
  Validates and prepares a Binance Spot order for execution.
  """

  use Lux.Prism,
    name: "Binance Spot Order",
    description: "Validates and builds order payload for Binance Spot trading",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Trading pair symbol, e.g. BTCUSDT"},
        side: %{type: :string, description: "BUY or SELL"},
        type: %{type: :string, default: "LIMIT"},
        quantity: %{type: :number, description: "Base asset quantity"},
        price: %{type: :number, description: "Limit order price"},
        time_in_force: %{type: :string, default: "GTC"}
      },
      required: ["symbol", "side", "quantity"]
    },
    output_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string},
        side: %{type: :string},
        type: %{type: :string},
        quantity: %{type: :number},
        status: %{type: :string}
      },
      required: ["symbol", "side", "quantity", "status"]
    }

  alias Lux.Integrations.Binance.SpotTrading

  def handler(input, _ctx) do
    case SpotTrading.build_order_params(input) do
      {:ok, params} ->
        {:ok, Map.put(params, :status, "validated")}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
