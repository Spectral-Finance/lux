defmodule Lux.Prisms.Binance.FuturesOrderPrism do
  @moduledoc """
  Validates and prepares a Binance USDⓈ-M Futures order.
  """

  use Lux.Prism,
    name: "Binance Futures Order",
    description: "Validates and builds order payload for Binance USDⓈ-M Perpetual Futures trading",
    input_schema: %{
      type: :object,
      properties: %{
        symbol: %{type: :string, description: "Perpetual symbol, e.g. BTCUSDT"},
        side: %{type: :string, description: "BUY or SELL"},
        type: %{type: :string, default: "LIMIT"},
        quantity: %{type: :number, description: "Contract quantity"},
        price: %{type: :number, description: "Order limit price"},
        position_side: %{type: :string, default: "BOTH"},
        reduce_only: %{type: :boolean, default: false}
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

  alias Lux.Integrations.Binance.FuturesTrading

  def handler(input, _ctx) do
    case FuturesTrading.build_futures_order(input) do
      {:ok, params} ->
        {:ok, Map.put(params, :status, "validated")}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
